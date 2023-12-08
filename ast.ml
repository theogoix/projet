open Lexing

(* Syntaxe abstraite juste après parsing *)

type binop = Add | Sub | Mul | Div          (* integer binops *)
           | Eq | Gt | Ge | Lt | Le | Neq   (* comparison binops *)
           | Conc                           (* string binop *)
           | And | Or                       (* bool binops *)

type constant = 
  | Cint of int
  | Cbool of bool
  | Cstring of string

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
  | Ecase         of expr list * (pattern list * expr) list
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



(* déclaration groupées *)

type gdecl_desc = (* grouped_declarations*)
  | GDefData         of string * string list * (string * tpe list) list
  | GDefClass
  | GDefInstance
  | GDefFun          of string * string list * unit list * tpe list * tpe * (pattern list * expr) list (*combine DefTypefun et une liste de DefEqfun*)
and gdecl = {gdecl_desc : gdecl_desc ; loc : position*position}


(* AST après typage *)

type t_expr_desc =
  | TEcst          of constant
  | TEvar          of string
  | TEbinop        of binop * t_expr * t_expr
  | TEif           of t_expr * t_expr * t_expr
  | TEdo           of t_expr list
  | TElet          of t_bind list * t_expr
  | TEcase         of t_expr * (pattern * t_expr) list
  | TEappli        of string * t_expr list
  | TEconstr       of string * t_expr list
  | TEgetconstr    of t_expr
  | TEgetarg       of t_expr * int
and t_expr = {expr_desc : t_expr_desc ; loc : position*position; typ : Typing_def.typ}
and t_bind = string * t_expr



