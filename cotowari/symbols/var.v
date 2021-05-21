module symbols

import cotowari.util { auto_id }
import cotowari.source { Pos }
import cotowari.errors { unreachable }

pub struct Var {
mut:
	scope &Scope = 0
pub:
	name string
	id   u64
	pos  Pos
pub mut:
	typ Type = builtin_type(.placeholder)
}

pub fn (v Var) is_function() bool {
	return v.type_symbol().is_function()
}

pub fn (v Var) str() string {
	return 'Var{ name: $v.name, scope: $v.scope_str(), typ: $v.typ }'
}

pub fn (v Var) scope() ?&Scope {
	return Symbol(v).scope()
}

fn (v Var) scope_str() string {
	return Symbol(v).scope_str()
}

pub fn (v Var) full_name() string {
	return Symbol(v).full_name()
}

pub fn (v Var) type_symbol() TypeSymbol {
	if scope := v.scope() {
		return scope.lookup_type(v.typ) or { unresolved_type_symbol }
	}
	return unresolved_type_symbol
}

// -- lookup / register --

fn (mut s Scope) check_before_register_var(v Var) ? {
	key := v.name
	if key in s.vars {
		return error('$key is exists')
	}
}

pub fn (mut s Scope) register_var(v Var) ?Var {
	s.check_before_register_var(v) ?
	new_v := Var{
		...v
		id: if v.id == 0 { auto_id() } else { v.id }
		scope: s
	}
	s.vars[new_v.name] = new_v
	return new_v
}

pub fn new_placeholder_var(name string) Var {
	return Var{
		name: name
		typ: builtin_type(.placeholder)
	}
}

fn (mut s Scope) must_register_var(v Var) Var {
	return s.register_var(v) or { panic(unreachable) }
}

pub fn (s &Scope) lookup_var(name string) ?Var {
	if name in s.vars {
		return s.vars[name]
	}
	if p := s.parent() {
		return p.lookup_var(name)
	}
	return none
}

pub fn (s &Scope) must_lookup_var(name string) Var {
	return s.lookup_var(name) or { panic(unreachable) }
}

pub fn (mut s Scope) lookup_or_register_var(v Var) Var {
	return s.lookup_var(v.name) or { s.register_var(v) or { panic(unreachable) } }
}
