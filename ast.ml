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
  | PatAny
and pattern = {pattern_desc : pattern_desc ; loc : position*position}

type tpe_desc =
  | TypeVar           of string
  | TypeConstr        of string * tpe list
and tpe = {tpe_desc : tpe_desc ; loc : position*position}

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
  | Eforcetype    of expr * tpe
and expr = {expr_desc : expr_desc ; loc : position*position}
and bind = string * expr


type decl_desc =
  | DefData         of string * string list * (string * tpe list) list
  | DefClass        of string * string list * decl list
  | DefInstance
  | DefTypefun      of string * string list * unit list * tpe list * tpe 
                    (* f:: forall a1 ... ak => I1 ... Il -> t1 ... tm -> t*)
  | DefEqfun        of string * pattern list * expr
and decl = {decl_desc : decl_desc ; loc : position*position}



(* déclaration groupées *)

type gdecl_desc = (* grouped_declarations*)
  | GDefData         of string * string list * (string * tpe list) list
  | GDefClass        of string * string list * decl list
  | GDefInstance
  | GDefFun          of string * string list * unit list * tpe list * tpe * expr (*combine DefTypefun et une liste de DefEqfun*)
and gdecl = {gdecl_desc : gdecl_desc ; loc : position*position}


(* AST après typage *)

type t_expr_desc =
  | TEcst          of constant
  | TEvar          of int
  | TEbinop        of binop * t_expr * t_expr
  | TEif           of t_expr * t_expr * t_expr
  | TEdo           of t_expr list
  | TElet          of t_bind list * t_expr
  | TEcase         of t_expr list * (pattern list * t_expr) list
  | TEswitch       of t_expr * (int * t_expr) list * int option * t_expr
  | TEappli        of string * t_expr list
  | TEconstr       of string * t_expr list
  | TEgetconstr    of t_expr
  | TEgetarg       of t_expr * int
and t_expr = {expr_desc : t_expr_desc ; typ : Typing_def.typ}
and t_bind = int * t_expr

type effective_pattern =
| EPatVar          of int
| EPatConstructor  of string * int * effective_pattern list (*nom de la data * numéro de constructeur * args *)
| EPatConstant     of constant
| EPatAny

type t_fun = string * int * int * t_expr
        (*nom * nb d'arg * nb d'alloc * expr*)

type t_program = t_fun list

