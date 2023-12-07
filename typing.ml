
(* TD 6 Unification et algorithme W -- version avec unification destructive *)

(* types et variables de types sont définis mutuellement récursivement *)

open Ast
open Format
open Errors

type typ =
  | Tint
  | Tbool
  | Tstring
  | Tarrow of typ * typ
  | Tproduct of typ * typ
  | Tvar of tvar

and tvar =
  { id : int;
    mutable def : typ option }

(* module V pour les variables de type *)

module V = struct
  type t = tvar
  let compare v1 v2 = Stdlib.compare v1.id v2.id
  let equal v1 v2 = v1.id = v2.id
  let create = let r = ref 0 in fun () -> incr r; { id = !r; def = None }
end

(* réduction en tête d'un type (la compression de chemin serait possible) *)
let rec head = function
  | Tvar { def = Some t } -> head t
  | t -> t

(* forme canonique d'un type = on applique head récursivement *)
let rec canon t = match head t with
  | Tvar _ | Tint | Tbool | Tstring as t -> t
  | Tarrow (t1, t2) -> Tarrow (canon t1, canon t2)
  | Tproduct (t1, t2) -> Tproduct (canon t1, canon t2)

(* pretty printer de type *)
let rec pp_typ fmt = function
  | Tproduct (t1, t2) -> Format.fprintf fmt "%a *@ %a" pp_atom t1 pp_atom t2
  | Tarrow (t1, t2) -> Format.fprintf fmt "%a ->@ %a" pp_atom t1 pp_typ t2
  | (Tint | Tbool | Tstring | Tvar _) as t -> pp_atom fmt t
and pp_atom fmt = function
  | Tint -> Format.fprintf fmt "Int"
  | Tbool -> Format.fprintf fmt "Bool"
  | Tstring -> Format.fprintf fmt "String"
  | Tvar v -> pp_tvar fmt v
  | Tarrow _ | Tproduct _ as t -> Format.fprintf fmt "@[<1>(%a)@]" pp_typ t
and pp_tvar fmt = function
  | { def = None; id } -> Format.fprintf fmt "'%d" id
  | { def = Some t; id } -> Format.fprintf fmt "@[<1>('%d := %a)@]" id pp_typ t


let rec string_of_typ = function
| Tint -> "Int"
| Tbool -> "Bool"
| Tstring -> "String"
| Tarrow(t1, t2) -> string_of_typ t1 ^ " -> " ^ string_of_typ t2
| Tproduct(t1, t2) -> string_of_typ t1 ^ " * " ^ string_of_typ t2
| Tvar(v) -> match v.def with
    | None -> "Var " ^ string_of_int v.id
    | Some t -> "(Var " ^ string_of_int v.id ^ " = " ^ string_of_typ t ^ ")"


(* unification *)

exception UnificationFailure of typ * typ

let unification_error t1 t2 = raise (UnificationFailure (canon t1, canon t2))

let rec occur v t = match head t with
  | Tvar w -> V.equal v w
  | Tarrow (t1, t2) | Tproduct (t1, t2) -> occur v t1 || occur v t2
  | Tint | Tbool | Tstring -> false

let rec unify t1 t2 = match head t1, head t2 with
  | Tint, Tint ->
      ()
  | Tbool, Tbool ->
      ()
  | Tstring, Tstring ->
      ()
  | Tvar v1, Tvar v2 when V.equal v1 v2 ->
      ()
  | Tvar v1 as t1, t2 ->
      if occur v1 t2 then unification_error t1 t2;
      assert (v1.def = None);
      v1.def <- Some t2
  | t1, Tvar v2 ->
      unify t2 t1
  | Tarrow (t11, t12), Tarrow (t21, t22)
  | Tproduct (t11, t12), Tproduct (t21, t22) ->
      unify t11 t21; unify t12 t22
  | t1, t2 ->
      unification_error t1 t2


let cant_unify ty1 ty2 =
  try let _ = unify ty1 ty2 in false with UnificationFailure _ -> true


(* schéma de type *)

module Vset = Set.Make(V)

type schema = { vars : Vset.t; typ : typ }

(* variables libres *)

let rec fvars t = match head t with
  | Tint | Tbool | Tstring -> Vset.empty
  | Tarrow (t1, t2) | Tproduct (t1, t2) -> Vset.union (fvars t1) (fvars t2)
  | Tvar v -> Vset.singleton v

let norm_varset s =
  Vset.fold (fun v s -> Vset.union (fvars (Tvar v)) s) s Vset.empty


(* environnement c'est une table bindings (string -> schema),
   et un ensemble de variables de types libres *)

module Smap = Map.Make(String)

type env = { bindings : schema Smap.t; fvars : Vset.t }

let empty = { bindings = Smap.empty; fvars = Vset.empty }

let add gen x t env =
  let vt = fvars t in
  let s, fvars =
    if gen then
      let env_fvars = norm_varset env.fvars in
      { vars = Vset.diff vt env_fvars; typ = t }, env.fvars
    else
      { vars = Vset.empty; typ = t }, Vset.union env.fvars vt
  in
  { bindings = Smap.add x s env.bindings; fvars = fvars }

module Vmap = Map.Make(V)

(* find x env donne une instance fraîche de env(x) *)
let find x env =
  let tx = Smap.find x env.bindings in
  let s =
    Vset.fold (fun v s -> Vmap.add v (Tvar (V.create ())) s)
      tx.vars Vmap.empty
  in
  let rec subst t = match head t with
    | Tvar x as t -> (try Vmap.find x s with Not_found -> t)
    | Tint -> Tint
    | Tbool -> Tbool
    | Tstring -> Tstring
    | Tarrow (t1, t2) -> Tarrow (subst t1, subst t2)
    | Tproduct (t1, t2) -> Tproduct (subst t1, subst t2)
  in
  subst tx.typ



let typ_of_tpe



(* algorithme W *)
let rec w_expr env (expr:expr) = match expr.expr_desc with
  | Evar x ->
      find x env
  | Ecst c ->
      begin match c.constant_desc with
        | Cbool _ -> Tbool
        | Cint _ -> Tint
        | Cstring _ -> Tstring
      end
  | Ebinop (op, e1, e2) -> 
      begin match op.binop_desc with
        | Add | Sub | Mul | Div ->
          let t1 = w_expr env e1 in
          let t2 = w_expr env e2 in
          if cant_unify Tint t1 then begin
              localisation e1.loc;
              eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t1);
              exit 1 end;
          if cant_unify Tint t2 then begin
              localisation e2.loc;
              eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t2);
              exit 1 end;
            Tint
        | And | Or ->
          let t1 = w_expr env e1 in
          let t2 = w_expr env e2 in
          if cant_unify Tbool t1 then begin
              localisation e1.loc;
              eprintf "Typing error: This expression should have type Bool but has type %s instead@." (string_of_typ t1);
              exit 1 end;
          if cant_unify Tbool t2 then begin
              localisation e2.loc;
              eprintf "Typing error: This expression should have type Bool but has type %s instead@." (string_of_typ t2);
              exit 1 end;
            Tbool
        | Gt | Ge | Lt | Le ->
          let t1 = w_expr env e1 in
          let t2 = w_expr env e2 in
          if cant_unify Tint t1 then begin
              localisation e1.loc;
              eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t1);
              exit 1 end;
          if cant_unify Tint t2 then begin
              localisation e2.loc;
              eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t2);
              exit 1 end;
            Tbool
        | Conc ->
          let t1 = w_expr env e1 in
          let t2 = w_expr env e2 in
          if cant_unify Tstring t1 then begin
              localisation e1.loc;
              eprintf "Typing error: This expression should have type String but has type %s instead@." (string_of_typ t1);
              exit 1 end;
          if cant_unify Tstring t2 then begin
              localisation e2.loc;
              eprintf "Typing error: This expression should have type String but has type %s instead@." (string_of_typ t2);
              exit 1 end;
            Tstring
        | Eq | Neq ->
          let t1 = w_expr env e1 in
          let t2 = w_expr env e2 in
          if cant_unify t1 t2 then begin
              localisation expr.loc;
              eprintf "Typing error: Trying to compare types %s and %s@." (string_of_typ t1) (string_of_typ t2);
              exit 1 end;
          if cant_unify t1 Tint && cant_unify t1 Tbool && cant_unify t1 Tstring then begin
              localisation expr.loc;
              eprintf "Typing error: Trying to compare types %s and %s@." (string_of_typ t1) (string_of_typ t2);
              exit 1 end;
            Tbool
        end
 (* | Pair (e1, e2) ->
      let t1 = w env e1 in
      let t2 = w env e2 in
      Tproduct (t1, t2) *)
 (* | Fun (x, e1) ->
      let v = Tvar (V.create ()) in
      let env = add false x v env in
      let t1 = w env e1 in
      Tarrow (v, t1) *)
(*  | App (e1, e2) ->
      let t1 = w env e1 in
      let t2 = w env e2 in
      let v = Tvar (V.create ()) in
      unify t1 (Tarrow (t2, v));
      v *)
  | Elet (li, e) ->
      w_expr (List.fold_left add_binding_gen env li) e
  | _ -> failwith("misssing case in W")

and add_binding_gen env bind = 
  let x, e = bind in
  let t = w_expr env e in
  add true x t env



let rec check_coherent_decl = function
| t :: q -> 
  begin match t.gdecl_desc with
    | GDefFun(_, _, _, _, _, li) -> let env = empty in check_coherent_equations env li ; check_coherent_decl q
    | _ -> check_coherent_decl q
  end
| [] -> ()
and check_coherent_equations env = function
| (pats, e) :: q -> let _ = w_expr env e in check_coherent_equations env q
| [] -> ()