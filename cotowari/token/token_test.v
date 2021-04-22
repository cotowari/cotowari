module token

import cotowari.source { none_pos, pos }

fn test_eq() {
	t := Token{.unknown, 'text', pos(i: 10)}

	assert t == Token{
		...t
		pos: none_pos
	}
	assert t != Token{
		...t
		pos: pos({})
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

fn test_is() {
	assert TokenKind.op_plus.@is(.op)
	assert !TokenKind.ident.@is(.op)
	assert TokenKind.op_eq.@is(.comparsion_op)
	assert !TokenKind.ident.@is(.comparsion_op)
	assert TokenKind.op_eq.@is(.binary_op)
	assert !TokenKind.ident.@is(.binary_op)
	assert TokenKind.op_not.@is(.prefix_op)
	assert !TokenKind.ident.@is(.prefix_op)
	assert TokenKind.op_plus_plus.@is(.suffix_op)
	assert !TokenKind.ident.@is(.suffix_op)
	assert TokenKind.bool_lit.@is(.literal)
	assert !TokenKind.ident.@is(.literal)
	assert TokenKind.key_if.@is(.keyword)
	assert !TokenKind.ident.@is(.keyword)
}
