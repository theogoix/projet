open Lexing
open Format
open Ast
open Errors

(*
Vérification que les déclarations de fonctions sont bien de la forme:
f::type...
f x11 ... x1n = e1
      ...
f xk1 ... xkn = e1
avec une seule colone qui n'a pas que des variables et remplacer ça par un case avec une seule définition pour f
*)

let rec group_fun decl_li = match decl_li with
  | t::q ->
    begin match t.decl_desc with
      | DefData(id, vars, li) -> {gdecl_desc = GDefData(id, vars, li) ; loc = t.loc }:: (group_fun q)
      | DefClass -> {gdecl_desc = GDefClass ; loc = t.loc } :: (group_fun q)
      | DefInstance -> {gdecl_desc = GDefInstance ; loc = t.loc } :: (group_fun q)
      | DefTypefun(id, foralls, insts, args, ret) -> let q2, eqs = find_equations q id [] in {gdecl_desc = GDefFun(id, foralls, insts, args, ret, eqs) ; loc = t.loc} :: (group_fun q2)
      | DefEqfun(f, _, _) -> 
        localisation t.loc;
        eprintf "Typing error: Unexpected equation defining %s@." f;
        exit 1
    end
 | [] -> []
and find_equations decl_li id eqs = 
  match decl_li with
    | t::q ->
      begin match t.decl_desc with
      | DefEqfun(id2, pat_li, e) ->
        if id = id2 then
          find_equations q id ((pat_li, e)::eqs) 
        else begin
          localisation t.loc;
          eprintf "Typing error: Unexpected equation defining %s@." id2;
          exit 1 end
      | _ -> decl_li, eqs
      end
    | _ -> decl_li, eqs


