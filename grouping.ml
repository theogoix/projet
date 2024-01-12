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

let arg_name n = "@" ^ string_of_int n;;

(* associe à n la liste des expressions de variables @0, @1, ... @n-1*)
let arg_list loc n = List.map (fun n -> {expr_desc = Evar(arg_name n); loc = loc}) (List.init n (fun x->x))

let rec group_fun decl_li = match decl_li with
  | t::q ->
    begin match t.decl_desc with
      | DefData(id, vars, li) -> {gdecl_desc = GDefData(id, vars, li) ; loc = t.loc }:: (group_fun q)
      | DefClass(id, vars, li) -> {gdecl_desc = GDefClass(id, vars, li) ; loc = t.loc } :: (group_fun q)
      | DefInstance -> {gdecl_desc = GDefInstance ; loc = t.loc } :: (group_fun q)
      | DefTypefun(id, foralls, insts, args, ret) ->
          let arg_num = List.length args in
          let q2, eqs, total_loc = find_equations q id arg_num [] t.loc in
          {gdecl_desc = GDefFun(id, foralls, insts, args, ret, {expr_desc = Ecase(arg_list total_loc arg_num, List.rev eqs);
                                                                loc = total_loc}) ;
           loc = t.loc}
           :: (group_fun q2)
      | DefEqfun(f, _, _) -> 
        localisation t.loc;
        eprintf "Typing error: Unexpected equation defining %s@." f;
        exit 1
    end
 | [] -> []
and find_equations decl_li id arg_num eqs total_loc = 
  match decl_li with
    | t::q ->
      begin match t.decl_desc with
      | DefEqfun(id2, pat_li, e) ->
        if id = id2 then
          let total_loc_start, _ = total_loc in
          let _, total_loc_end = t.loc in
          if List.length pat_li <> arg_num then begin
            localisation t.loc;
            eprintf "Typing error: Function %s takes %d arguments but equation has %d patterns@." id arg_num (List.length pat_li);
            exit 1 end;
          find_equations q id arg_num ((pat_li, e)::eqs) (total_loc_start, total_loc_end)
        else begin
          localisation t.loc;
          eprintf "Typing error: Unexpected equation defining %s@." id2;
          exit 1 end
      | _ -> decl_li, eqs, total_loc
      end
    | [] -> decl_li, eqs, total_loc


