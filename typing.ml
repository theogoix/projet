 


(* Copié collé de ce que j'ai fait au TD6 *)


type typ =
| Tint
| Tbool
| Tstring
| Tarrow of typ * typ
| Tproduct of typ * typ (* pas nécéssaire ? *)
| Tvar of tvar

and tvar =
{ id : int;
  mutable def : typ option } ;;


(* pretty printer*)

let rec pp_typ fmt = function
| Tproduct (t1, t2) -> Format.fprintf fmt "%a *@ %a" pp_atom t1 pp_atom t2
| Tarrow (t1, t2) -> Format.fprintf fmt "%a ->@ %a" pp_atom t1 pp_typ t2
| _ as t -> pp_atom fmt t
and pp_atom fmt = function
| Tint -> Format.fprintf fmt "int"
| Tbool -> Format.fprintf fmt "bool"
| Tstring -> Format.fprintf fmt "string"
| Tvar v -> pp_tvar fmt v
| Tarrow _ | Tproduct _ as t -> Format.fprintf fmt "@[<1>(%a)@]" pp_typ t
and pp_tvar fmt = function
| { def = None; id } -> Format.fprintf fmt "'%d" id
| { def = Some t; id } -> Format.fprintf fmt "@[<1>('%d := %a)@]" id pp_typ t ;;


module V = struct
type t = tvar
let compare v1 v2 = Stdlib.compare v1.id v2.id
let equal v1 v2 = v1.id = v2.id
let create = let r = ref 0 in fun () -> incr r; { id = !r; def = None }
end


(* QUESTION 1 *)

let rec head t = match t with
| Tvar({id = _; def = Some t2}) -> head t2
| _ -> t ;;

let rec canon t = match t with
| Tvar({def = Some t2}) -> canon t2
| Tproduct(t1, t2) -> Tproduct(canon t1, canon t2)
| Tarrow(t1, t2) -> Tarrow(canon t1, canon t2)
| _ -> t ;;


(* QUESTION 2 *)

exception UnificationFailure of typ * typ;;

let unification_error t1 t2 = raise (UnificationFailure (canon t1, canon t2));;

let rec occur tv t = match head t with
| Tint | Tbool | Tstring -> false
| Tproduct(t1, t2) -> occur tv t1 || occur tv t2
| Tarrow(t1, t2) -> occur tv t1 || occur tv t2
| Tvar({id = i}) -> i = tv.id;;


let rec unify t1 t2 = match (head t1, head t2) with
| Tint, Tint -> ()
| Tbool, Tbool -> ()
| Tstring, Tstring -> ()
| Tproduct(t1a, t1b), Tproduct(t2a, t2b) -> unify t1a t2a ; unify t1b t2b
| Tarrow(t1a, t1b), Tarrow(t2a, t2b) -> unify t1a t2a ; unify t1b t2b
| Tvar(tv), _ -> tv.def <- Some (head t2)
| _ , Tvar(tv) -> tv.def <- Some (head t1)
| _ -> unification_error t1 t2;;


let cant_unify ty1 ty2 =
try let _ = unify ty1 ty2 in false with UnificationFailure _ -> true;;

(* QUESTION 3 *)

module Vset = Set.Make(V)

let rec fvars t = match head t with
| Tint | Tbool | Tstring -> Vset.empty
| Tproduct(t1, t2) -> Vset.union (fvars t1) (fvars t2)
| Tarrow(t1, t2) -> Vset.union (fvars t1) (fvars t2) 
| Tvar(v) -> Vset.singleton v ;;


(* QUESTION 4 *)

type schema = { vars : Vset.t; typ : typ };;

module Smap = Map.Make(String);;

type env = { bindings : schema Smap.t; fvars : Vset.t };;

let empty = {bindings = Smap.empty ; fvars = Vset.empty};;


let add str t env = {bindings = Smap.(env.bindings |> add str { vars = Vset.empty; typ = t }) ; fvars = Vset.union env.fvars (fvars t)};;

let add_gen str t env = {bindings = Smap.(env.bindings |> add str { vars = Vset.diff (fvars t) env.fvars; typ = t }) ; fvars = env.fvars};;

module Vmap = Map.Make(V)

(* renoie un Vmap de tvar qui a chaque variable de type libre dans
   le schéma associe une variable fraiche *)
let rec substitutions vlist = 
match vlist with
  | [] -> Vmap.empty
  | a :: q -> let subs = substitutions q in Vmap.(subs |> add a (V.create ()))

(* avec le Vmap précédent, remplace toutes les occurences par les
   variables fraiches dans t *)
let rec substitute subs t = match head t with
  | Tint | Tbool | Tstring -> t
  | Tproduct(t1, t2) -> Tproduct(substitute subs t1, substitute subs t2)
  | Tarrow(t1, t2) -> Tarrow(substitute subs t1, substitute subs t2)
  | Tvar(tv) -> let replacement = Vmap.find_opt tv subs in
                match replacement with
                  | None -> t
                  | Some tv2 -> Tvar(tv2)


let find str env =
let sigma = Smap.find str env.bindings in
substitute (substitutions (Vset.elements sigma.vars)) sigma.typ


(* TODO : question 5 du TD en gros *)

open Ast

let rec w env = function
  | Evar x ->
      find x env
  | Ecst (Cint _) ->
      Tint
  | Ecst (Cbool _) ->
      Tbool
  | Ecst (Cstring _) ->
      Tstring
  | Ebinop (op, e1, e2) ->
    begin match op with
      | Add | Sub | Mul | Div ->
        let t1 = w env e1 in
        let t2 = w env e2 in
        unify t1 Tint;
        unify t2 Tint;
        Tint
      | Gt | Ge | Lt | Le ->
          let t1 = w env e1 in
          let t2 = w env e2 in
          unify t1 Tint;
          unify t2 Tint;
          Tbool
      | Conc ->
          let t1 = w env e1 in
          let t2 = w env e2 in
          unify t1 Tstring;
          unify t2 Tstring;
          Tstring
      | And | Or ->
          let t1 = w env e1 in
          let t2 = w env e2 in
          unify t1 Tbool;
          unify t2 Tbool;
          Tbool
      | _ -> failwith "missing binop in W"
    end
(*  | Fun (x, e1) ->
      let v = Tvar (V.create ()) in
      let env = add false x v env in
      let t1 = w env e1 in
      Tarrow (v, t1)*)
(*  | App (e1, e2) ->
      let t1 = w env e1 in
      let t2 = w env e2 in
      let v = Tvar (V.create ()) in
      unify t1 (Tarrow (t2, v));
      v*)
  | Elet(li, e) ->
      w (List.fold_left add_binding_gen env li) e
  | _ -> failwith "missing case in W"

and add_binding_gen env bind = 
  let x, e = bind in
  let t = w env e in
  add_gen x t env