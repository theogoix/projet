
(* TD 6 Unification et algorithme W -- version avec unification destructive *)

(* types et variables de types sont définis mutuellement récursivement *)

open Ast
open Format
open Errors
open Typing_def
open Lexing
open Grouping

(* unification *)

exception UnificationFailure of typ * typ

let unification_error t1 t2 = raise (UnificationFailure (t1, t2))

let rec occur v t = match head t with
  | Tvar w -> V.equal v w
  | Tarrow (li, t2) -> List.fold_left (fun b t -> b || occur v t) false li || occur v t2
  | Tdata (_, li) -> List.fold_left (fun b t -> b || occur v t) false li
  | Tproduct (t1, t2) -> occur v t1 || occur v t2
  | Tint | Tbool | Tstring | Tunit -> false

let rec unify t1 t2 = match head t1, head t2 with
  | Tint, Tint ->
      ()
  | Tbool, Tbool ->
      ()
  | Tstring, Tstring ->
      ()
  | Tunit, Tunit ->
      ()
  | Tdata(id1, li1), Tdata(id2, li2) ->
      begin try List.iter2 unify li1 li2 with Invalid_argument(_) -> unification_error t1 t2 end
  | Tvar v1, Tvar v2 when V.equal v1 v2 ->
      ()
  | Tvar v1 as t1, t2 ->
      if occur v1 t2 then unification_error t1 t2;
      assert (v1.def = None);
      v1.def <- Some t2
  | t1, Tvar v2 ->
      unify t2 t1
  | Tarrow (li1, t21), Tarrow (li2, t22) ->
    unify t21 t22; (try List.iter2 unify li1 li2 with Invalid_argument(_) -> unification_error t1 t2)
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
  | Tint | Tbool | Tstring | Tunit -> Vset.empty
  | Tdata (_, li) -> List.fold_left (fun set t -> Vset.union set (fvars t)) Vset.empty li
  | Tarrow (li, t2) -> Vset.union (List.fold_left (fun set t -> Vset.union set (fvars t)) Vset.empty li) (fvars t2)
  | Tproduct (t1, t2) -> Vset.union (fvars t1) (fvars t2)
  | Tvar v -> Vset.singleton v

let norm_varset s =
  Vset.fold (fun v s -> Vset.union (fvars (Tvar v)) s) s Vset.empty


(* environnement c'est une table bindings (string -> schema),
   et un ensemble de variables de types libres *)

module Smap = Map.Make(String)

type env = { bindings : schema Smap.t; fvars : Vset.t; type_bindings : tvar Smap.t }

let empty = { bindings = Smap.empty; fvars = Vset.empty; type_bindings = Smap.empty }

let add gen x t env =
  let vt = fvars t in
  let s, fvars =
    if gen then
      let env_fvars = norm_varset env.fvars in
      { vars = Vset.diff vt env_fvars; typ = t }, env.fvars
    else
      { vars = Vset.empty; typ = t }, Vset.union env.fvars vt
  in
  { bindings = Smap.add x s env.bindings; fvars = fvars; type_bindings = env.type_bindings }

let add_tvar x tv env = { bindings = env.bindings; fvars = env.fvars; type_bindings = Smap.add x tv env.type_bindings }


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
    | Tunit -> Tunit
    | Tstring -> Tstring
    | Tdata (id, li) -> Tdata (id, List.map subst li)
    | Tarrow (li, t2) -> Tarrow (List.map subst li, subst t2)
    | Tproduct (t1, t2) -> Tproduct (subst t1, subst t2)
  in
  subst tx.typ






let datas = ref Smap.empty;; (* Smap des datas et de leur variables de types *)
datas := Smap.add "Effect" [V.create ()] !datas;;

let classes = ref Smap.empty;; (* Smap des classes et de leur variables de types *)
datas := Smap.add "Show" [V.create ()] !classes;;



let texpr desc loc t = {expr_desc = desc ; loc = loc; typ = t};;



let first_of_list li = match li with
  | t::_ -> t
  | [] -> failwith "first from empty list"

let remove_first li = match li with
  | _::q -> q
  | [] -> failwith "remove_first from empty list"


let rec typ_of_tpe var_names tpe = match tpe.tpe_desc with
| TypeVar(x) -> begin try Tvar (Smap.find x var_names) with 
    Not_found -> 
      Errors.localisation tpe.loc;
      eprintf "Typing error: Unkown type variable %s@." x;
      exit 1 end
| TypeConstr(id, li) -> match id with
  | "Int" -> Tint
  | "Bool" -> Tbool
  | "Unit" -> Tunit
  | "String" -> Tstring
  | _ -> Tdata(id, List.map (typ_of_tpe var_names) li)




let rec type_pattern env pat = match pat.pattern_desc with
| PatConstant(Cint(_)) -> Tint, env
| PatConstant(Cbool(_)) -> Tbool, env
| PatConstant(Cstring(_)) -> Tstring, env
| PatVar(x) -> let tv = V.create() in Tvar(tv), add false x (Tvar tv) env
| PatConstructor(f, pat_li) -> 
    let tf = find f env in
    begin match tf with
      | Tarrow (typ_li, t_ret) ->
        let env = List.fold_left2
        begin fun env typ pat -> 
          let t_pat, env = type_pattern env pat in
          if cant_unify t_pat typ then begin
            Errors.localisation pat.loc;
            eprintf "Typing error: This pattern should have type %s but has type %s instead@." (string_of_typ typ) (string_of_typ t_pat);
            exit 1 end;
          env
        end
        env typ_li pat_li in
        t_ret, env
       |_ -> failwith "oups" end



(* algorithme W *)
let rec w_expr env (expr:expr) = match expr.expr_desc with

  | Evar x ->
      begin try texpr (TEvar x) expr.loc (find x env) with
      Not_found -> 
        Errors.localisation expr.loc;
        eprintf "Typing error: Unkown variable %s@." x;
        exit 1 end

        
  | Ecst c ->
      let t = begin match c with
        | Cbool _ -> Tbool
        | Cint _ -> Tint
        | Cstring _ -> Tstring
      end in
      texpr (TEcst c) expr.loc t


  | Ebinop (op, e1, e2) -> 
      let te1 = w_expr env e1 in
      let te2 = w_expr env e2 in
      let t1 = te1.typ in
      let t2 = te2.typ in
      let t = begin match op with
        | Add | Sub | Mul | Div ->
          if cant_unify Tint t1 then begin
            Errors.localisation e1.loc;
            eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t1);
            exit 1 end;
          if cant_unify Tint t2 then begin
            Errors.localisation e2.loc;
            eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t2);
            exit 1 end;
          Tint
        | And | Or ->
          if cant_unify Tbool t1 then begin
            Errors.localisation e1.loc;
            eprintf "Typing error: This expression should have type Bool but has type %s instead@." (string_of_typ t1);
            exit 1 end;
          if cant_unify Tbool t2 then begin
            Errors.localisation e2.loc;
            eprintf "Typing error: This expression should have type Bool but has type %s instead@." (string_of_typ t2);
            exit 1 end;
          Tbool
        | Gt | Ge | Lt | Le ->
          if cant_unify Tint t1 then begin
            Errors.localisation e1.loc;
            eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t1);
            exit 1 end;
          if cant_unify Tint t2 then begin
            Errors.localisation e2.loc;
            eprintf "Typing error: This expression should have type Int but has type %s instead@." (string_of_typ t2);
            exit 1 end;
          Tbool
        | Conc ->
          if cant_unify Tstring t1 then begin
            Errors.localisation e1.loc;
            eprintf "Typing error: This expression should have type String but has type %s instead@." (string_of_typ t1);
            exit 1 end;
          if cant_unify Tstring t2 then begin
            Errors.localisation e2.loc;
            eprintf "Typing error: This expression should have type String but has type %s instead@." (string_of_typ t2);
            exit 1 end;
          Tstring
        | Eq | Neq ->
          if cant_unify t1 t2 then begin
            Errors.localisation expr.loc;
            eprintf "Typing error: Trying to compare types %s and %s@." (string_of_typ t1) (string_of_typ t2);
            exit 1 end;
          if cant_unify t1 Tint && cant_unify t1 Tbool && cant_unify t1 Tstring then begin
            Errors.localisation expr.loc;
            eprintf "Typing error: Trying to compare types %s and %s@." (string_of_typ t1) (string_of_typ t2);
            exit 1 end;
          Tbool
        end in
      texpr (TEbinop (op, te1, te2)) expr.loc t


  | Eif (e1,e2,e3) -> 
      let te1 = w_expr env e1 in
      let t1 = te1.typ in
      if cant_unify Tbool t1 then begin 
        Errors.localisation e1.loc;
        eprintf "Typing error : Type bool expected, got type %s@." (string_of_typ t1);
        exit 1 end;
      let te2 = w_expr env e2 in
      let te3 = w_expr env e3 in
      let t2 = te2.typ in
      let t3 = te3.typ in
      if cant_unify t2 t3 then begin 
        Errors.localisation e2.loc;
        Errors.localisation e3.loc;
        eprintf "Typing error : both branches of if ... else should have same type but got %s and %s instead@." (string_of_typ t2) (string_of_typ t3);
        exit 1 end; 
      texpr (TEif (te1, te2, te3)) expr.loc t2


  | Eappli (f, expr_li) ->
      let tf = begin try find f env with
      Not_found -> 
        Errors.localisation expr.loc;
        eprintf "Typing error: Unkown function %s@." f;
        exit 1 end
      in
      begin match tf with
      | Tarrow (typ_li, t_ret) ->
        let check te_li e expected_t =
          let te = w_expr env e in
          let t = te.typ in
          if cant_unify t expected_t then begin
            Errors.localisation e.loc;
            eprintf "Typing error: Type %s expected, got type %s@." (string_of_typ t) (string_of_typ expected_t);
            exit 1 end;
          te::te_li
        in
        let li = begin try List.fold_left2 check [] expr_li typ_li with
          Invalid_argument(_) ->
            Errors.localisation expr.loc;
            eprintf "Typing error: Wrong number of argument for function %s@." f;
            exit 1
        end in
        texpr (TEappli(f, li)) expr.loc t_ret
      | _ -> 
        Errors.localisation expr.loc;
        eprintf "Typing error: Trying to apply variable %s which is not a function@." f;
        exit 1
      end


  | Econstr (f, expr_li) -> (* + ou - idem à Eappli *)
      let tf = begin try find f env with
      Not_found -> 
        Errors.localisation expr.loc;
        eprintf "Typing error: Unkown constructor %s@." f;
        exit 1 end
      in
      begin match tf with
      | Tarrow (typ_li, t_ret) ->
        let check te_li e expected_t =
          let te = w_expr env e in
          let t = te.typ in
          if cant_unify t expected_t then begin
            Errors.localisation e.loc;
            eprintf "Typing error: Type %s expected, got type %s@." (string_of_typ t) (string_of_typ expected_t);
            exit 1 end;
          te::te_li
        in
        let li = begin try List.fold_left2 check [] expr_li typ_li with
          Invalid_argument(_) ->
            Errors.localisation expr.loc;
            eprintf "Typing error: Wrong number of argument for constructor %s@." f;
            exit 1
        end in
        texpr (TEappli(f, li)) expr.loc t_ret
      | _ -> 
        Errors.localisation expr.loc;
        eprintf "Typing error: Trying to apply variable %s which is not a constructor@." f;
        exit 1
      end


  | Edo (li) -> 
    let te_li = List.fold_left
    begin fun te_li e ->
      let te = w_expr env e in 
      let t = te.typ in 
      if cant_unify (Tdata("Effect", [Tunit])) t then begin
        Errors.localisation e.loc;
        eprintf "Typing error: This expression should have type Effect Unit but has type %s instead@." (string_of_typ t);
        exit 1 end;
      te::te_li
    end
    [] li in
    texpr (TEdo(te_li)) expr.loc (Tdata("Effect", [Tunit]))


  | Elet (bind_li, e) ->

      let tbind_of_bind_aux tbind_li (bind:bind) = let (x, e) = bind in (x, w_expr env e):: tbind_li in
      let tbind_li = List.fold_left tbind_of_bind_aux [] bind_li in (*On transfomre tous les bindings en bindings typés *)

      let add_binding_gen env bind = 
        let x, e = bind in
        let t = (w_expr env e).typ in
        add true x t env 
      in
      let te = w_expr (List.fold_left add_binding_gen env bind_li) e in
      texpr (TElet(tbind_li, te)) expr.loc te.typ


  | Eforcetype(e, tpe) ->
      let te = w_expr env e in
      let expected_typ = typ_of_tpe env.type_bindings tpe in
      if cant_unify te.typ expected_typ then begin
        Errors.localisation expr.loc;
        eprintf "Typing error: This expression is said to have type %s but has type %s instead@." (string_of_typ expected_typ) (string_of_typ te.typ);
        exit 1 end;
      te
  
  
  | Ecase(expr_li, branch_li) ->
      let texpr_li = List.map
      (w_expr env)
      expr_li in

      let tbranch_li = List.map
      begin fun branch ->
        let pats, e = branch in
        let env = List.fold_left2
        begin fun env pat (te:t_expr) ->
          let pat_type, env = type_pattern env pat in
          if cant_unify pat_type te.typ then begin
            Errors.localisation expr.loc;
            eprintf "Typing error: This pattern has type %s but should have type %s@." (string_of_typ pat_type) (string_of_typ te.typ);
            exit 1 end;
          env
        end
        env pats texpr_li in 
        pats, w_expr env e
      end
      branch_li 
      in

      match tbranch_li with
        | [] -> begin
          Errors.localisation expr.loc;
          eprintf "Typing error: Empty case@.";
          exit 1 end;
        | branch1::q ->
          let _, te1 = branch1 in
          let t1 = te1.typ in
          List.iter
          (fun branch -> 
            let _, (te:t_expr) = branch in
            let t = te.typ in
            if cant_unify t t1 then begin
              Errors.localisation te.loc;
              eprintf "Typing error: This branch has type %s while the first branch has type %s@." (string_of_typ t) (string_of_typ t1);
              exit 1 end
              )
          q;
          texpr (TEcase(texpr_li, tbranch_li)) expr.loc t1




(*and f env (arg_li:t_expr list) (branch_li:(pattern list * expr) list) = 
  match branch_li with
    | [] -> 
      Errors.localisation expr.loc;
      eprintf "Typing error: Non-exhaustive pattern-matching@.";
      exit 1
    | branch1::_ ->
      let pats1, e1 = branch1 in
      match pats1 with
        | [] -> w_expr env e1
        | pat11 :: pats1 -> 
          if 
            List.for_all 
            (fun branch -> let pats, _ = branch in let p = first_of_list pats in match p.pattern_desc with
            | PatVar(_) -> true
            | _ -> false)
            branch_li
          then
            let arg1 = first_of_list arg_li in
            List.map
            (fun branch -> )
          ;*)


let remove_empty_arrows t = match t with
| Tarrow([], t) -> t
|_ -> t





let rec type_decl env gdecl_li =
  match gdecl_li with
  | gdecl :: q -> 
    begin match gdecl.gdecl_desc with

      | GDefFun(f, foralls, instances, args, ret, expr) -> (* On type la fonction et on l'ajoute à l'environement *)

      (* Check pour ne pas redéfinir *)
        begin match Smap.find_opt f env.bindings with
          | None -> ()
          | Some _ -> begin
            Errors.localisation gdecl.loc;
            eprintf "Typing error: Redefining function %s@." f;
            exit 1 end;
        end;

          (* On récupère les foralls en leur donnant des varibles de types *)
          let var_list, var_names = List.fold_left
          (fun (var_list, var_names) a -> let tv = V.create () in tv::var_list, Smap.add a tv var_names)
          ([], Smap.empty) foralls
          in

          let arg_types = List.map (typ_of_tpe var_names) args in
          let ret_type = typ_of_tpe var_names ret in

          let schema = (* shéma de type de f*)
          {vars = Vset.of_list var_list ;
          typ = remove_empty_arrows (Tarrow(arg_types, ret_type)) }
          in

        let bindings = (*on donne les types aux arguments @0, @1, ... @n-1  *)
          List.fold_left2
          begin fun bindings typ n ->
            Smap.add (arg_name n) {typ = typ ; vars = Vset.of_list var_list} bindings
          end
          env.bindings arg_types (List.init (List.length arg_types) (fun x->x))
        in
        
        (* On type l'expression *)
        let te = w_expr { bindings = Smap.add f schema bindings ; fvars = env.fvars; type_bindings = var_names } expr in

        let t = te.typ in
        if cant_unify t ret_type then begin
          Errors.localisation expr.loc;
          eprintf "Typing error: Function %s should return %s, returns %s instead@." f (string_of_typ ret_type) (string_of_typ t);
          exit 1 end;
        
        (* On vérifie que les variables de tpyes des foralls n'ont pas été définies *)

        List.iter (* TODO: écrire le nom de la variable blutot que son id *)
        begin fun tv -> match tv.def with
          | Some t -> begin
            Errors.localisation expr.loc;
            eprintf "Typing error: Forall type variable %s was reduced to type %s in function %s@." (string_of_int tv.id) (string_of_typ t) f;
            exit 1 end
          | None -> ()
        end
        var_list;

        type_decl { bindings = Smap.add f schema env.bindings ; fvars = env.fvars; type_bindings = env.type_bindings } q


      | GDefData(id, foralls, constructors) ->

        (* Check pour ne pas redéfinir *)
        begin match Smap.find_opt id !datas with
          | None -> ()
          | Some _ -> begin
            Errors.localisation gdecl.loc;
            eprintf "Typing error: Redefining data type %s@." id;
            exit 1 end;
        end;


        let var_list, var_names = List.fold_left
        (fun (var_list, var_names) a -> let tv = V.create () in tv::var_list, Smap.add a tv var_names)
        ([], Smap.empty) foralls
        in
        datas := Smap.add id var_list !datas;
        let env = List.fold_left
        begin fun env constr ->
          let cid, args = constr in
          let arg_types = List.map (typ_of_tpe var_names) args in
          let ret_type = Tdata(id, List.map (fun tv -> Tvar(tv)) var_list) in
          let schema = 
          {vars = Vset.of_list var_list ;
          typ = Tarrow(arg_types, ret_type) }
          in
          { bindings = Smap.add cid schema env.bindings ; fvars = env.fvars; type_bindings = env.type_bindings }
        end
        env constructors in
        type_decl env q


      | GDefClass(id, vars, decl_li) ->

        (* Check pour ne pas redéfinir *)
        begin match Smap.find_opt id !classes with
          | None -> ()
          | Some _ -> begin
            Errors.localisation gdecl.loc;
            eprintf "Typing error: Redefining class %s@." id;
            exit 1 end;
        end;


        let var_list, var_names = List.fold_left
        (fun (var_list, var_names) a -> let tv = V.create () in tv::var_list, Smap.add a tv var_names)
        ([], Smap.empty) vars
        in

        (* On rajoute à l'environnement les fonction de la classe *)
        let env = List.fold_left
        begin fun env decl -> match decl.decl_desc with
          | DefTypefun(f, foralls, instances, args, ret) ->

            (* On récupère les foralls en leur donnant des varibles de types *)
            let var_list, var_names = List.fold_left
            begin fun (var_list, var_names) a ->
              match Smap.find_opt a var_names with
              | None -> let tv = V.create () in tv::var_list, Smap.add a tv var_names 
              | Some _ -> var_list, var_names 
            end
            (var_list, var_names) foralls
            in

            let arg_types = List.map (typ_of_tpe var_names) args in
            let ret_type = typ_of_tpe var_names ret in

            let schema = (* shéma de type de la fonction*)
            {vars = Vset.of_list var_list ;
            typ = remove_empty_arrows (Tarrow(arg_types, ret_type)) }
            in
            { bindings = Smap.add f schema env.bindings ; fvars = env.fvars; type_bindings = env.type_bindings }
          |_ -> 
            localisation decl.loc;
            eprintf "Typing error: Expected type declaration@."; (* Ne devrait jamais arriver *)
            exit 1 end
        env decl_li
        in


        classes := Smap.add id var_list !classes;

        type_decl env q


      | _ -> type_decl env q
    end
  | [] -> ()


let type_file decl_li = 
  let a = V.create() in
  let env = {
    bindings = 
      Smap.(empty |> add "log" { vars = Vset.empty; typ = Tarrow([Tstring], Tdata("Effect", [Tunit])) }
                  |> add "not" { vars = Vset.empty; typ = Tarrow([Tbool], Tbool) }
                  |> add "mod" { vars = Vset.empty; typ = Tarrow([Tint; Tint], Tint) }
                  |> add "unit" { vars = Vset.empty; typ = Tunit }
                  |> add "pure" { vars = Vset.singleton a; typ = Tarrow([Tvar(a)], Tdata("Effect", [Tvar(a)])) } );
    fvars = Vset.empty; type_bindings = Smap.empty } 
  in
  type_decl env decl_li
