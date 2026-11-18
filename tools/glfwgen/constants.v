// Resolve GLFW's integer macros without evaluating arbitrary source text.
module glfwgen

import strconv

struct ConstantExpression {
	text   string
	values map[string]i64
mut:
	offset int
}

fn (mut expr ConstantExpression) skip_space() {
	for expr.offset < expr.text.len && expr.text[expr.offset].is_space() {
		expr.offset++
	}
}

fn (mut expr ConstantExpression) operand() !i64 {
	expr.skip_space()
	if expr.offset >= expr.text.len {
		return error('expected an operand')
	}
	ch := expr.text[expr.offset]
	if ch == `(` {
		expr.offset++
		value := expr.evaluate(1)!
		expr.skip_space()
		if expr.offset == expr.text.len || expr.text[expr.offset] != `)` {
			return error('missing closing parenthesis')
		}
		expr.offset++
		return value
	}
	if ch in [u8(`+`), `-`, `~`] {
		expr.offset++
		value := expr.operand()!
		return match ch {
			`-` { -value }
			`~` { ~value }
			else { value }
		}
	}
	start := expr.offset
	for expr.offset < expr.text.len && identifier_char(expr.text[expr.offset]) {
		expr.offset++
	}
	if start == expr.offset {
		return error('invalid operand at ${expr.text[start..]}')
	}
	token := expr.text[start..expr.offset]
	if ch.is_digit() {
		return strconv.parse_int(token, 0, 64)
	}
	return expr.values[token] or { error('constant ${token} has not been defined') }
}

fn operator(text string) (string, int) {
	if text.starts_with('<<') || text.starts_with('>>') {
		return text[..2], 3
	}
	if text.len > 0 {
		return match text[0] {
			`|` { '|', 1 }
			`&` { '&', 2 }
			`+` { '+', 4 }
			`-` { '-', 4 }
			else { '', 0 }
		}
	}
	return '', 0
}

fn (mut expr ConstantExpression) evaluate(min_precedence int) !i64 {
	mut left := expr.operand()!
	for {
		expr.skip_space()
		op, precedence := operator(expr.text[expr.offset..])
		if precedence < min_precedence {
			return left
		}
		expr.offset += op.len
		right := expr.evaluate(precedence + 1)!
		if op in ['<<', '>>'] && (right < 0 || right >= 64) {
			return error('invalid shift width ${right}')
		}
		left = match op {
			'|' { left | right }
			'&' { left & right }
			'+' { left + right }
			'-' { left - right }
			'<<' { i64(u64(left) << right) }
			'>>' { left >> right }
			else { return error('unsupported operator ${op}') }
		}
	}
	return left
}

fn numeric_constants(source string) map[string]i64 {
	mut result := map[string]i64{}
	for line in source.split_into_lines() {
		fields := line.fields()
		if fields.len < 5 || fields[..2] != ['pub', 'const'] || fields[3] != '=' {
			continue
		}
		if value := strconv.parse_int(fields[4], 0, 64) {
			result[fields[2]] = value
		}
	}
	return result
}

fn constants(header string, handwritten string) ![]string {
	existing := numeric_constants(handwritten)
	mut values := map[string]i64{}
	mut result := []string{}
	for line in header.split_into_lines() {
		name, raw := macro(line) or { continue }
		text := strip_block_comments(raw)!
		mut expression := ConstantExpression{
			text:   text.trim_space()
			values: values
		}
		value := expression.evaluate(1) or {
			return error('unparsed GLFW constant ${name}: ${err}')
		}
		if expression.offset != expression.text.len {
			return error('unparsed GLFW constant ${name}: ${raw}')
		}
		values[name] = value
		short_name := name['GLFW_'.len..].to_lower()
		v_name := if short_name in ['true', 'false'] { '_${short_name}' } else { short_name }
		if recorded := existing[v_name] {
			if recorded != value {
				return error('handwritten constant ${v_name} differs from ${name}')
			}
		} else {
			literal := if value > 0x7fffffff { 'u32(${value})' } else { value.str() }
			result << 'pub const ${v_name} = ${literal}'
		}
	}
	return result
}
