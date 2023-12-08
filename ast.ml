open Lexing

(* Syntaxe abstraite juste après parsing *)

type binop_desc = Add | Sub | Mul | Div          (* integer binops *)
           | Eq | Gt | Ge | Lt | Le | Neq   (* comparison binops *)
           | Conc                           (* string binop *)
           | And | Or                       (* bool binops *)
and binop = {binop_desc : binop_desc ; loc : position*position}

type constant_desc = 
  | Cint of int
  | Cbool of bool
  | Cstring of string
and constant = {constant_desc : constant_desc ; loc : position*position}

type pattern_desc =
  | PatVar          of string
  | PatConstructor  of string * pattern list
  | PatConstant     of constant
and pattern = {pattern_desc : pattern_desc ; loc : position*position}

type expr_desc =
  | Ecst          of constant
  | Evar          of string
  | Ebinop        of binop * expr * expr
  | Eif           of expr * expr * expr   (* if <expr> then <expr> else <expr> *)
  | Edo           of expr list
  | Elet          of bind list * expr
  | Ecase         of expr * (pattern * expr) list
  | Eappli        of string * expr list
  | Econstr       of string * expr list
and expr = {expr_desc : expr_desc ; loc : position*position}
and bind = string * expr

type tpe_desc =
  | TypeVar           of string
  | TypeConstr        of string * tpe list
and tpe = {tpe_desc : tpe_desc ; loc : position*position}

type decl_desc =
  | DefData         of string * string list * (string * tpe list) list
  | DefClass
  | DefInstance
  | DefTypefun      of string * string list * unit list * tpe list * tpe 
                    (* f:: forall a1 ... ak => I1 ... Il -> t1 ... tm -> t*)
  | DefEqfun        of string * pattern list * expr
and decl = {decl_desc : decl_desc ; loc : position*position}

type gdecl_desc = (* grouped_declarations*)
  | GDefData         of string * string list * (string * tpe list) list
  | GDefClass
  | GDefInstance
  | GDefFun          of string * string list * unit list * tpe list * tpe * (pattern list * expr) list (*combine DefTypefun et une liste de DefEqfun*)
and gdecl = {gdecl_desc : gdecl_desc ; loc : position*position}




