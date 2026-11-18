// Parse the declarations supported by the GLFW binding generator.
module glfwgen

import strconv
import strings

const scalar_types = {
	'char':           'char'
	'unsigned char':  'u8'
	'short':          'i16'
	'unsigned short': 'u16'
	'int':            'i32'
	'unsigned int':   'u32'
	'uint32_t':       'u32'
	'uint64_t':       'u64'
	'size_t':         'usize'
	'float':          'f32'
	'double':         'f64'
}

pub struct Prototype {
pub:
	name        string
	return_type string
	parameters  []string
}

struct CPrototype {
	name       string
	result     string
	parameters string
}

struct HeaderStruct {
	name string
	body string
}

struct HeaderTypes {
	names           map[string]string
	no_arg_callback map[string]bool
}

fn (types HeaderTypes) v_type(declaration string) !string {
	c_type := declaration.replace('*', ' * ').fields().filter(it != 'const').join(' ')
	depth := c_type.count('*')
	base := c_type.replace('*', '').fields().join(' ')
	if base == 'void' {
		return if depth == 0 { '' } else { 'voidptr' }
	}
	if base in types.no_arg_callback {
		return 'voidptr'
	}
	mapped := scalar_types[base] or {
		types.names[base] or {
			if base.starts_with('Vk') {
				'vk.' + base[2..]
			} else if base.starts_with('PFN_vk') {
				'vk.' + base
			} else if base.starts_with('GLFW') {
				base
			} else {
				return error('unsupported C type: ${base}')
			}
		}
	}
	return '&'.repeat(depth) + mapped
}

fn identifier_char(ch u8) bool {
	return ch.is_alnum() || ch == `_`
}

fn split_declaration(declaration string) !(string, string) {
	text := declaration.trim_space()
	mut start := text.len
	for start > 0 && identifier_char(text[start - 1]) {
		start--
	}
	if start == 0 || start == text.len || text[start].is_digit() {
		return error('expected a type and name in "${declaration}"')
	}
	return text[..start].trim_space(), text[start..]
}

fn (types HeaderTypes) parameter(declaration string) !string {
	mut text := declaration.trim_space()
	mut pointer_suffix := ''
	if text.ends_with(']') {
		open := text.last_index('[') or { return error('invalid array parameter: ${text}') }
		text = text[..open]
		pointer_suffix = '*'
	}
	c_type, _ := split_declaration(text)!
	mapped := types.v_type(c_type + pointer_suffix)!
	if mapped == '' {
		return error('void parameter in ${declaration}')
	}
	return mapped
}

fn raw_prototype(declaration string) !CPrototype {
	left, right := declaration.split_once('(') or {
		return error('missing parameters: ${declaration}')
	}
	if !right.ends_with(');') {
		return error('unterminated prototype: ${declaration}')
	}
	result, name := split_declaration(left)!
	return CPrototype{name, result, right[..right.len - 2].trim_space()}
}

fn (types HeaderTypes) prototype(raw CPrototype) !Prototype {
	mut params := []string{}
	if raw.parameters != 'void' {
		for param in raw.parameters.split(',') {
			params << types.parameter(param) or { return error('${raw.name}: ${err}') }
		}
	}
	return Prototype{raw.name, types.v_type(raw.result)!, params}
}

fn prototypes(header string) ![]CPrototype {
	mut result := []CPrototype{}
	// Public declarations begin with GLFWAPI. Join wrapped declarations before parsing.
	mut declaration := ''
	for line in header.split_into_lines() {
		if line.starts_with('GLFWAPI ') {
			if declaration != '' {
				return error('unterminated declaration: ${declaration}')
			}
			declaration = line['GLFWAPI '.len..].trim_space()
		} else if declaration != '' {
			declaration += ' ' + line.trim_space()
		}
		if declaration.ends_with(';') {
			prototype := raw_prototype(declaration)!
			if !prototype.name.starts_with('glfw') {
				return error('unexpected GLFWAPI declaration: ${declaration}')
			}
			result << prototype
			declaration = ''
		}
	}
	if declaration != '' {
		return error('unterminated declaration: ${declaration}')
	}
	if result.len == 0 {
		return error('header contains no GLFWAPI declarations')
	}
	return result
}

fn callbacks(header string) ![]CPrototype {
	mut result := []CPrototype{}
	for line in header.split_into_lines() {
		if !line.starts_with('typedef ') || !line.contains('(*') {
			continue
		}
		left, right := line.split_once('(*') or { continue }
		name, args := right.split_once(')') or { return error('invalid callback: ${line}') }
		callback := raw_prototype(left['typedef '.len..].trim_space() + ' ' + name.trim_space() +
			args)!
		result << callback
	}
	return result
}

fn header_structs(header string) ![]HeaderStruct {
	mut result := []HeaderStruct{}
	for declaration in header.split('typedef struct ')[1..] {
		name := declaration.fields()[0]
		if !name.starts_with('GLFW') {
			continue
		}
		rest := declaration[name.len..].trim_space()
		if rest.starts_with('{') {
			body, closing := rest[1..].split_once('}') or {
				return error('unterminated struct ${name}')
			}
			if !closing.trim_space().starts_with('${name};') {
				return error('unexpected alias for struct ${name}')
			}
			result << HeaderStruct{name, body}
		} else if rest.starts_with('${name};') {
			result << HeaderStruct{name, ''}
		}
	}
	return result
}

fn strip_block_comments(text string) !string {
	mut clean := strings.new_builder(text.len)
	mut rest := text
	for {
		before, after := rest.split_once('/*') or { break }
		clean.write_string(before)
		clean.write_u8(` `)
		_, remainder := after.split_once('*/') or { return error('unterminated C comment') }
		rest = remainder
	}
	clean.write_string(rest)
	return clean.str()
}

fn v_names(source string) map[string]string {
	mut result := map[string]string{}
	for line in source.split_into_lines() {
		words := line.fields()
		if words.len == 5 && words[..2] == ['pub', 'type'] && words[3] == '='
			&& words[4].starts_with('C.GLFW') {
			result[words[4][2..]] = words[2]
		}
	}
	return result
}

fn handwritten_types(source string) map[string]bool {
	mut result := map[string]bool{}
	for line in source.split_into_lines() {
		words := line.fields()
		if words.len > 2 && words[..2] == ['pub', 'type'] {
			result[words[2]] = true
		}
	}
	return result
}

fn c_functions(source string) map[string]bool {
	mut result := map[string]bool{}
	for line in source.split_into_lines() {
		if line.starts_with('fn C.glfw') {
			name := line['fn C.'.len..].all_before('(')
			result[name] = true
		}
	}
	return result
}

fn snake(name string) string {
	mut builder := strings.new_builder(name.len)
	for index, ch in name.trim_string_left('glfw') {
		if index > 0 && ch >= `A` && ch <= `Z` {
			builder.write_u8(`_`)
		}
		builder.write_u8(ch)
	}
	return builder.str().to_lower()
}

fn (types HeaderTypes) struct_fields(declaration HeaderStruct) ![]string {
	body := strip_block_comments(declaration.body)!
	mut fields := []string{}
	for raw_field in body.split(';') {
		mut field := raw_field.trim_space()
		if field == '' {
			continue
		}
		mut dimension := ''
		if field.ends_with(']') {
			open := field.last_index('[') or { return error('invalid array field: ${field}') }
			count := field[open + 1..field.len - 1]
			if count == '' || !count.bytes().all(it.is_digit()) {
				return error('unsupported array size in ${field}')
			}
			dimension = field[open..]
			field = field[..open]
		}
		c_type, name := split_declaration(field) or { return error('${declaration.name}: ${err}') }
		fields << '\t${name} ${dimension}${types.v_type(c_type)!}'
	}
	return fields
}

fn macro(line string) ?(string, string) {
	if !line.starts_with('#define ') {
		return none
	}
	text := line['#define '.len..].trim_space()
	end := text.index_any(' \t')
	if end < 0 || !text.starts_with('GLFW_') || !text[..end].bytes().all(identifier_char(it)) {
		return none
	}
	return text[..end], text[end..].trim_space()
}

// header_version reads the version macros for a downloaded or vendored header.
pub fn header_version(header string) !string {
	mut parts := map[string]string{}
	for line in header.split_into_lines() {
		name, value := macro(line) or { continue }
		if name in ['GLFW_VERSION_MAJOR', 'GLFW_VERSION_MINOR', 'GLFW_VERSION_REVISION'] {
			part := strconv.parse_uint(value, 10, 31) or {
				return error('invalid GLFW header version macro ${name}')
			}
			parts[name] = part.str()
		}
	}
	if parts.len != 3 {
		return error('missing GLFW header version macros')
	}
	return '${parts['GLFW_VERSION_MAJOR']}.${parts['GLFW_VERSION_MINOR']}.${parts['GLFW_VERSION_REVISION']}'
}
