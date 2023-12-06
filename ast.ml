 
(* Syntaxe abstraite juste après parsing *)

type binop = Add | Sub | Mul | Div          (* integer binops *)
           | Eq | Gt | Ge | Lt | Le | Neq   (* comparison binops *)
           | Conc                           (* string binop *)
           | And | Or                       (* bool binops *)

type constant = 
  | Cint of int
  | Cbool of bool
  | Cstring of string

type pattern =
  | PatVar          of string
  | PatConstructor  of string * pattern list
  | PatConstant     of constant

type expr =
  | Ecst          of constant
  | Evar          of string
  | Ebinop        of binop * expr * expr
  | Eif           of expr * expr * expr   (* if <expr> then <expr> else <expr> *)
  | Edo           of expr list
  | Elet          of bind list * expr
  | Ecase         of expr * (pattern * expr) list
  | Eappli        of string * expr list
  | Econstr       of string * expr list

and bind = string * expr

type tpe =
  | TypeVar           of string
  | TypeConstr        of string * tpe list

type decl =
  | DefData
  | DefClass
  | DefInstance
  | DefTypefun      of string * string list * unit list * tpe list * tpe 
                    (* f:: forall a1 ... ak => I1 ... Il -> t1 ... tm -> t*)
  | DefEqfun        of string * pattern list * expr

type gdecl = (* grouped_declarations*)
  | GDefData
  | GDefClass
  | GDefInstance
  | GDefFun          of string * string list * unit list * tpe list * tpe * (pattern list * expr) list (*combine DefTypefun et une liste de DefEqfun*)


(*
Vérification que les déclarations de fonctions sont bien de la forme:
f::type...
f x11 ... x1n = e1
      ...
f xk1 ... xkn = e1
avec une seule colone qui n'a pas que des variables et remplacer ça par un case avec une seule définition pour f
*)

let rec group_fun decl_li = match decl_li with
 | DefData::q -> GDefData :: (group_fun q)
 | DefClass::q -> GDefClass :: (group_fun q)
 | DefInstance::q -> GDefInstance :: (group_fun q)
 | DefTypefun(id, foralls, insts, args, ret)::q -> let q2, eqs = find_equations q id [] in GDefFun(id, foralls, insts, args, ret, eqs) :: (group_fun q2)
 | [] -> []
 | _ -> failwith "equation de fonction mal placée (remplacer ce message par une erreur propre)"
and find_equations decl_li id eqs = 
  match decl_li with
    | DefEqfun(id, pat_li, e)::q -> find_equations q id ((pat_li, e)::eqs)
    | _ -> decl_li, eqs


