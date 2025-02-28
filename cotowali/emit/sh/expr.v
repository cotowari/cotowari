// Copyright (c) 2021-2023 zakuro <z@kuro.red>
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
module sh

import cotowali.ast
import cotowali.token
import cotowali.symbols { builtin_type }
import cotowali.util { Tuple2, li_panic, tuple2 }

type ExprOrString = ast.Expr | string

enum ExprEmitMode {
	normal
	command
	condition
	inside_arithmetic
}

[params]
struct ExprOpt {
mut:
	mode           ExprEmitMode = .normal
	expand_array   bool
	writeln        bool
	discard_stdout bool
	quote          bool = true
}

struct ExprWithOpt[T] {
	expr T       [required]
	opt  ExprOpt [required]
}

fn expr_with_opt[T](expr T, opt ExprOpt) ExprWithOpt[T] {
	return ExprWithOpt[T]{expr, opt}
}

struct ExprWithValue[T, U] {
	expr  T [required]
	value U [required]
}

fn expr_with_value[T, U](expr T, v U) ExprWithValue[T, U] {
	return ExprWithValue[T, U]{expr, v}
}

fn (mut e Emitter) expr_or_string(expr ExprOrString, opt ExprOpt) {
	match expr {
		ast.Expr { e.expr(expr, opt) }
		string { e.write_echo_if_command_then_write(expr, opt) }
	}
}

fn (mut e Emitter) expr(expr ast.Expr, opt ExprOpt) {
	match expr {
		ast.AsExpr { e.as_expr(expr, opt) }
		ast.BoolLiteral { e.bool_literal(expr, opt) }
		ast.CallCommandExpr { e.call_command_expr(expr, opt) }
		ast.CallExpr { e.call_expr(expr, opt) }
		ast.DefaultValue { e.default_value(expr, opt) }
		ast.DecomposeExpr { e.decompose_expr(expr, opt) }
		ast.Empty {}
		ast.FloatLiteral { e.float_literal(expr, opt) }
		ast.IntLiteral { e.int_literal(expr, opt) }
		ast.ParenExpr { e.paren_expr(expr, opt) }
		ast.Pipeline { e.pipeline(expr, opt) }
		ast.InfixExpr { e.infix_expr(expr, opt) }
		ast.IndexExpr { e.index_expr(expr, opt) }
		ast.MapLiteral { e.map_literal(expr, opt) }
		ast.ModuleItem { e.module_item(expr, opt) }
		ast.Nameof { e.nameof(expr, opt) }
		ast.NullLiteral { e.null_literal(expr, opt) }
		ast.PrefixExpr { e.prefix_expr(expr, opt) }
		ast.SelectorExpr { e.selector_expr(expr, opt) }
		ast.ArrayLiteral { e.array_literal(expr, opt) }
		ast.StringLiteral { e.string_literal(expr, opt) }
		ast.Typeof { e.typeof_(expr, opt) }
		ast.Var { e.var_(expr, opt) }
	}
	e.write_if(opt.mode == .command && opt.discard_stdout, ' > /dev/null')
	e.writeln_if(opt.writeln, '')
}

fn (mut e Emitter) write_echo_if_command(opt ExprOpt) {
	e.write_if(opt.mode == .command, 'echo ')
}

fn (mut e Emitter) write_echo_if_command_then_write(s string, opt ExprOpt) {
	e.write_echo_if_command(opt)
	e.write(s)
}

fn (mut e Emitter) bool_literal(expr ast.BoolLiteral, opt ExprOpt) {
	v := if expr.bool() { true_value } else { false_value }
	if opt.mode == .condition {
		e.write(v)
	} else {
		e.write_echo_if_command_then_write(v, opt)
	}
}

fn (mut e Emitter) float_literal(expr ast.FloatLiteral, opt ExprOpt) {
	e.write_echo_if_command(opt)

	tmp_var := e.new_tmp_ident()
	e.insert_at(e.stmt_head_pos(), fn (mut e Emitter, v Tuple2[string, string]) {
		tmp_var, text := v.v1, v.v2
		e.write('${tmp_var}="\$(')
		{
			awk_code := '{printf "${printf_format_float}", \$1 }'
			e.write("echo ${text} | awk '${awk_code}'")
		}
		e.writeln(')"')
	}, tuple2(tmp_var, expr.token.text))
	e.write('\$${tmp_var}')
}

fn (mut e Emitter) int_literal(expr ast.IntLiteral, opt ExprOpt) {
	e.write_echo_if_command_then_write(expr.token.text, opt)
}

fn (mut e Emitter) null_literal(expr ast.NullLiteral, opt ExprOpt) {
	e.write_echo_if_command_then_write('/dev/null', opt)
}

fn (mut e Emitter) as_expr(expr ast.AsExpr, opt ExprOpt) {
	if call_expr := expr.overloaded_function_call_expr() {
		e.call_expr(call_expr, opt)
		return
	}
	e.expr(expr.expr, opt)
}

fn (mut e Emitter) decompose_expr(expr ast.DecomposeExpr, opt ExprOpt) {
	e.expr(expr.expr, ExprOpt{ ...opt, quote: false })
}

fn (mut e Emitter) default_value(expr ast.DefaultValue, opt ExprOpt) {
	e.write_echo_if_command(opt)

	ts := ast.Expr(expr).type_symbol()
	if tuple_info := ts.tuple_info() {
		e.paren_expr(ast.ParenExpr{
			scope: expr.scope
			exprs: tuple_info.elements.map(ast.Expr(ast.DefaultValue{
				typ: it.typ
				scope: expr.scope
			}))
		}, opt)
		return
	}

	e.write(match ts.resolved().typ {
		builtin_type(.bool) { false_value }
		builtin_type(.int), builtin_type(.float) { '0' }
		else { '' }
	})
}

fn (mut e Emitter) var_(v ast.Var, opt ExprOpt) {
	ident := e.ident_for(v)
	match ast.Expr(v).type_symbol().resolved().kind() {
		.array {
			e.array(ident, opt)
		}
		.map {
			e.map(ident, opt)
		}
		else {
			s := if opt.mode == .inside_arithmetic {
				// no need $ in arithmetic. e.g: $(( n == 0 ))
				'${ident}'
			} else if opt.quote {
				'"\${${ident}}"'
			} else {
				'\${${ident}}'
			}
			e.write_echo_if_command_then_write(s, opt)
		}
	}
}

fn (mut e Emitter) index_expr(expr ast.IndexExpr, opt ExprOpt) {
	if expr.left.resolved_typ() == builtin_type(.string) {
		e.index_expr_for_string(expr, opt)
		return
	}

	e.write_echo_if_command(opt)

	e.sh_command_substitution(fn (mut e Emitter, v ExprWithOpt[ast.IndexExpr]) {
		left_ts := v.expr.left.type_symbol().resolved()

		if tuple_info := left_ts.tuple_info() {
			tmp := e.new_tmp_ident()
			mut tmps := []string{cap: tuple_info.elements.len}
			for i in 0 .. tuple_info.elements.len {
				tmps << '${tmp}__${i}'
			}
			e.destructuring_assign(tmps, v.expr.left)
			e.write('echo \$${tmp}__')
			e.expr(v.expr.index, writeln: true)
			return
		}

		e.write(match left_ts.kind() {
			.array { 'array_get ' }
			.map { 'map_get ' }
			else { li_panic(@FN, @FILE, @LINE, 'invalid index left') }
		})

		e.expr(v.expr.left)
		e.write(' ')
		e.expr(v.expr.index, v.opt)
	}, expr_with_opt(expr, opt), opt)
}

fn (mut e Emitter) index_expr_for_string(expr ast.IndexExpr, opt ExprOpt) {
	if opt.mode != .command {
		e.sh_command_substitution_open(opt)
		defer {
			e.sh_command_substitution_close(opt)
		}
	}
	e.expr(expr.left, mode: .command)
	e.write(" | awk -v RS='' -v i=")
	e.expr(expr.index)
	e.write(' ')
	e.write('\'{printf "%s", substr(\$0, i + 1, 1) }\'')
}

fn (mut e Emitter) infix_expr(expr ast.InfixExpr, opt ExprOpt) {
	op := expr.op
	$if !prod {
		if !op.kind.@is(.infix_op) {
			li_panic(@FN, @FILE, @LINE, 'not a infix op')
		}
	}

	if call_expr := expr.overloaded_function_call_expr() {
		e.call_expr(call_expr, opt)
		return
	}

	ts := expr.left.type_symbol().resolved()

	match ts.typ {
		builtin_type(.int), builtin_type(.float) {
			e.infix_expr_for_number(expr, opt)
		}
		builtin_type(.string) {
			e.infix_expr_for_string(expr, opt)
		}
		builtin_type(.bool) {
			e.infix_expr_for_bool(expr, opt)
		}
		else {
			match ts.kind() {
				.array { e.infix_expr_for_array(expr, opt) }
				.tuple { e.infix_expr_for_tuple(expr, opt) }
				else { li_panic(@FN, @FILE, @LINE, 'invarid operand of infix expr (`${ts.name}`)') }
			}
		}
	}
}

fn (mut e Emitter) infix_expr_for_bool(expr ast.InfixExpr, opt ExprOpt) {
	$if !prod {
		if expr.left.resolved_typ() != builtin_type(.bool) {
			li_panic(@FN, @FILE, @LINE, 'not a bool operand')
		}
	}

	if expr.op.kind in [.eq, .ne] {
		e.sh_test_command_for_expr(fn (mut e Emitter, expr ast.InfixExpr) {
			op := if expr.op.kind == .eq { ' = ' } else { ' != ' }
			e.sh_test_cond_infix(expr.left, op, expr.right)
		}, expr, opt)
		return
	}

	op := match expr.op.kind {
		.logical_and { '&&' }
		.logical_or { '||' }
		else { li_panic(@FN, @FILE, @LINE, 'invalid op') }
	}

	if opt.mode == .command {
		e.write('( ')
		defer {
			e.write(' )')
			e.sh_result_to_bool()
		}
	}
	e.expr(expr.left, mode: .condition)
	e.write(' ${op} ')
	e.expr(expr.right, mode: .condition)
}

fn (mut e Emitter) infix_expr_for_number(expr ast.InfixExpr, opt ExprOpt) {
	$if !prod {
		if expr.left.resolved_typ() !in [builtin_type(.int), builtin_type(.float)] {
			li_panic(@FN, @FILE, @LINE, 'invalid operand')
		}
	}

	if builtin_type(.float) in [expr.left.resolved_typ(), expr.right.resolved_typ()] {
		e.infix_expr_for_float(expr, opt)
	} else {
		e.infix_expr_for_int(expr, opt)
	}
}

fn (mut e Emitter) infix_expr_for_float(expr ast.InfixExpr, opt ExprOpt) {
	$if !prod {
		if expr.left.resolved_typ() !in [builtin_type(.float),
			builtin_type(.int)] {
			li_panic(@FN, @FILE, @LINE, 'invalid operand')
		}
	}
	e.write_echo_if_command(opt)

	if expr.op.kind.@is(.comparsion_op) {
		e.sh_test_command_for_expr(fn (mut e Emitter, expr ast.InfixExpr) {
			e.sh_awk_infix_expr(expr)
			e.write(' -eq 1')
		}, expr, opt)
	} else {
		e.sh_awk_infix_expr(expr)
	}
}

fn (mut e Emitter) infix_expr_for_int(expr ast.InfixExpr, opt ExprOpt) {
	$if !prod {
		if expr.left.resolved_typ() != builtin_type(.int) {
			li_panic(@FN, @FILE, @LINE, 'invalid operand')
		}
	}

	e.write_echo_if_command(opt)

	if expr.op.kind.@is(.comparsion_op) {
		e.sh_test_command_for_expr(fn (mut e Emitter, expr ast.InfixExpr) {
			op := match expr.op.kind {
				.eq { '-eq' }
				.ne { '-ne' }
				.gt { '-gt' }
				.ge { '-ge' }
				.lt { '-lt' }
				.le { '-le' }
				else { li_panic(@FN, @FILE, @LINE, 'invalid op') }
			}
			e.sh_test_cond_infix(expr.left, op, expr.right)
		}, expr, opt)
		return
	}

	match expr.op.kind {
		.plus, .minus, .div, .mul, .mod {
			e.write_if(opt.mode != .inside_arithmetic, r'$(( ')
			{
				e.expr(expr.left, mode: .inside_arithmetic)
				e.write(' ${expr.op.text} ')
				e.expr(expr.right, mode: .inside_arithmetic)
			}
			e.write_if(opt.mode != .inside_arithmetic, ' ))')
		}
		.pow {
			e.sh_awk_infix_expr(expr)
		}
		else {
			li_panic(@FN, @FILE, @LINE, 'invalid op `${expr.op.text}`')
		}
	}
}

fn (mut e Emitter) infix_expr_for_string(expr ast.InfixExpr, opt ExprOpt) {
	$if !prod {
		if expr.left.resolved_typ() != builtin_type(.string) {
			li_panic(@FN, @FILE, @LINE, 'not a string operand')
		}
	}

	e.write_echo_if_command(opt)

	match expr.op.kind {
		.eq, .ne {
			e.sh_test_command_for_expr(fn (mut e Emitter, expr ast.InfixExpr) {
				op := if expr.op.kind == .eq { ' = ' } else { ' != ' }
				e.sh_test_cond_infix(expr.left, op, expr.right)
			}, expr, opt)
		}
		.plus {
			e.expr(expr.left)
			e.expr(expr.right)
		}
		else {
			li_panic(@FN, @FILE, @LINE, 'invalid op `${expr.op.text}`')
		}
	}
}

fn (mut e Emitter) infix_expr_for_tuple(expr ast.InfixExpr, opt ExprOpt) {
	$if !prod {
		if expr.left.type_symbol().resolved().kind() != .tuple {
			li_panic(@FN, @FILE, @LINE, 'not a string operand')
		}
	}

	e.write_echo_if_command(opt)

	match expr.op.kind {
		.eq, .ne {
			e.sh_test_command_for_expr(fn (mut e Emitter, expr ast.InfixExpr) {
				op := if expr.op.kind == .eq { ' = ' } else { ' != ' }
				e.sh_test_cond_infix(expr.left, op, expr.right)
			}, expr, opt)
		}
		.plus {
			e.expr(expr.left)
			e.write("' '")
			e.expr(expr.right)
		}
		else {
			li_panic(@FN, @FILE, @LINE, 'invalid op `${expr.op.text}`')
		}
	}
}

fn (mut e Emitter) module_item(expr ast.ModuleItem, opt ExprOpt) {
	$if !prod {
		if !expr.is_resolved() {
			li_panic(@FN, @FILE, @LINE, 'unresolved module item')
		}
	}
	e.expr(expr.item, opt)
}

fn (mut e Emitter) paren_expr(expr ast.ParenExpr, opt ExprOpt) {
	e.write_echo_if_command(opt)

	need_quote := opt.quote && opt.mode != .inside_arithmetic
		&& ast.Expr(expr).type_symbol().resolved().kind() == .tuple
	if need_quote {
		e.write('"')
		defer {
			e.write('"')
		}
	}

	mut subexpr_mode := ExprEmitMode.normal
	if opt.mode == .inside_arithmetic {
		subexpr_mode = opt.mode
		e.write(' (')
		defer {
			e.write(' )')
		}
	}

	for i, subexpr in expr.exprs {
		if i > 0 {
			e.write(' ')
		}
		e.expr(subexpr, mode: subexpr_mode)
	}
}

fn (mut e Emitter) prefix_expr(expr ast.PrefixExpr, opt ExprOpt) {
	op := expr.op
	$if !prod {
		if !op.kind.@is(.prefix_op) {
			li_panic(@FN, @FILE, @LINE, 'not a prefix op')
		}
	}

	if call_expr := expr.overloaded_function_call_expr() {
		e.call_expr(call_expr, opt)
		return
	}

	mut subexpr_opt := ExprOpt{
		...opt
	}
	if subexpr_opt.mode == .command {
		subexpr_opt.mode = .normal
	}

	e.write_echo_if_command(opt)
	match op.kind {
		.plus {
			e.expr(expr.expr, subexpr_opt)
		}
		.minus {
			infix_expr := expr.convert_to_infix_expr() or {
				li_panic(@FN, @FILE, @LINE, 'faild to convert to infix expr')
			}
			e.infix_expr(infix_expr, subexpr_opt)
		}
		.amp {
			e.reference(expr.expr)
		}
		.not {
			e.write('! { ')
			e.expr(expr.expr, mode: .condition)
			e.write(' ; }')
		}
		else {
			li_panic(@FN, @FILE, @LINE, 'invalid op `${expr.op.text}`')
		}
	}
}

fn (mut e Emitter) pipeline(expr ast.Pipeline, opt ExprOpt) {
	f := fn (mut e Emitter, pipeline ast.Pipeline) {
		for i, expr in pipeline.exprs {
			if i > 0 && i == pipeline.exprs.len - 1 && pipeline.has_redirect() {
				e.write(if pipeline.is_append { ' >> ' } else { ' > ' })
				e.expr(expr)
				return
			}

			if i > 0 {
				e.write(' | ')
			}
			e.expr(expr, mode: .command)
		}
	}
	if opt.mode == .command {
		f(mut e, expr)
	} else {
		e.sh_command_substitution(f, expr, opt)
	}
}

fn (mut e Emitter) selector_expr(expr ast.SelectorExpr, opt ExprOpt) {
	// selector expr is used for only method call now.
	// method call is handled by call_expr. Nothing to do
}
