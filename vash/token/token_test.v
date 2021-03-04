module token

import vash.pos

fn test_eq() {
	t := Token{.unknown, 'text', pos.new(i: 10)}

	assert t == Token{
		...t
		pos: pos.new_none()
	}
	assert t != Token{
		...t
		pos: pos.new({})
	}
	assert t != Token{
		...t
		kind: .eof
	}
	assert t != Token{
		...t
		text: 'x'
	}
}
