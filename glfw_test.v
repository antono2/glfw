module glfw

fn test_public_constants_and_types_compile() {
	assert _true == 1
	assert _false == 0
	assert press == 1
	assert release == 0
	assert repeat == 2
	assert no_api == 0
}
