module token

import cotowari.source { Pos }

pub enum TokenKind {
	unknown
	ident
	key_as
	key_assert
	key_fn
	key_let
	key_if
	key_else
	key_for
	key_in
	key_return
	key_decl
	key_require
	key_struct
	inline_shell
	comma
	hash
	dot
	dotdotdot
	amp
	question
	int_lit
	bool_lit
	string_lit
	l_paren
	r_paren
	l_brace
	r_brace
	l_bracket
	r_bracket
	op_pipe
	op_redirect
	op_plus
	op_minus
	op_div
	op_mul
	op_mod
	op_and
	op_or
	op_assign
	op_not
	op_eq
	op_ne
	op_gt
	op_ge
	op_lt
	op_le
	op_plus_plus
	op_minus_minus
	eol
	eof
}

[inline]
fn (k TokenKind) is_op() bool {
	return k in [
		.op_pipe,
		.op_redirect,
		.op_plus,
		.op_minus,
		.op_div,
		.op_mul,
		.op_mod,
		.op_and,
		.op_or,
		.op_assign,
		.op_not,
		.op_eq,
		.op_ne,
		.op_gt,
		.op_ge,
		.op_lt,
		.op_le,
	]
}

[inline]
fn (k TokenKind) is_comparsion_op() bool {
	return k in [
		.op_eq,
		.op_ne,
		.op_gt,
		.op_ge,
		.op_lt,
		.op_le,
	]
}

[inline]
fn (k TokenKind) is_prefix_op() bool {
	return k in [
		.op_plus,
		.op_minus,
		.op_not,
	]
}

[inline]
fn (k TokenKind) is_postfix_op() bool {
	return k in [
		.op_plus_plus,
		.op_minus_minus,
	]
}

[inline]
fn (k TokenKind) is_infix_op() bool {
	return k in [
		.op_pipe,
		.op_eq,
		.op_ne,
		.op_gt,
		.op_lt,
		.op_plus,
		.op_minus,
		.op_mul,
		.op_div,
		.op_mod,
		.op_and,
		.op_or,
	]
}

[inline]
fn (k TokenKind) is_literal() bool {
	return k in [
		.int_lit,
		.bool_lit,
		.string_lit,
	]
}

[inline]
fn (k TokenKind) is_keyword() bool {
	return k in [
		.key_as,
		.key_assert,
		.key_fn,
		.key_let,
		.key_if,
		.key_else,
		.key_for,
		.key_in,
		.key_return,
		.key_decl,
		.key_require,
		.key_struct,
	]
}

pub enum TokenKindClass {
	op
	comparsion_op
	infix_op
	prefix_op
	postfix_op
	literal
	keyword
}

[inline]
pub fn (k TokenKind) @is(class TokenKindClass) bool {
	return match class {
		.op { k.is_op() }
		.comparsion_op { k.is_comparsion_op() }
		.infix_op { k.is_infix_op() }
		.prefix_op { k.is_prefix_op() }
		.postfix_op { k.is_postfix_op() }
		.literal { k.is_literal() }
		.keyword { k.is_keyword() }
	}
}

pub struct Token {
pub:
	kind TokenKind
	text string
	pos  Pos
}

pub type TokenCond = fn (Token) bool

pub fn (lhs Token) == (rhs Token) bool {
	return if lhs.pos.is_none() || rhs.pos.is_none() {
		lhs.kind == rhs.kind && lhs.text == rhs.text
	} else {
		lhs.kind == rhs.kind && lhs.text == rhs.text && lhs.pos == rhs.pos
	}
}

[inline]
fn (t Token) text_for_str() string {
	return t.text.replace_each(['\\', '\\\\', '\n', r'\n', '\r', r'\r'])
}

pub fn (t Token) str() string {
	return "Token{ .$t.kind, '$t.text_for_str()', $t.pos }"
}

pub fn (t Token) short_str() string {
	return "{ .$t.kind, '$t.text_for_str()' }"
}
