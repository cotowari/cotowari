module checker

import cotowari.ast

fn (c Checker) expr(expr ast.Expr) {
	match expr {
		ast.CallFn {}
		ast.InfixExpr {}
		ast.IntLiteral {}
		ast.Pipeline {}
		ast.StringLiteral {}
		ast.Var {}
	}
}
