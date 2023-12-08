
(* TD 6 Unification et algorithme W -- version avec unification destructive *)

(* types et variables de types sont définis mutuellement récursivement *)

open Format

type typ =
  | Tint
  | Tbool
  | Tstring
  | Tunit
  | Tarrow    of typ list * typ
  | Tproduct  of typ * typ
  | Tvar      of tvar
  | Tdata     of string * typ list

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

(* réduction en tête d'un type *)
let rec head = function
  | Tvar { def = Some t } -> head t
  | t -> t

(* forme canonique d'un type = on applique head récursivement *)
(*let rec canon t = match head t with
  | Tvar _ | Tint | Tbool | Tstring | Tunit as t -> t
  | Tarrow (li, t2) -> Tarrow (List.map canon li, canon t2)
  | Tproduct (t1, t2) -> Tproduct (canon t1, canon t2) *)

(* pretty printer de type *)

(*
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
*)


let rec string_of_typ typ = match head typ with
| Tint -> "Int"
| Tbool -> "Bool"
| Tstring -> "String"
| Tunit -> "Unit"
| Tarrow(li, t2) -> List.fold_left (fun s t -> s ^ string_of_typ t ^ " -> ") "" li ^ string_of_typ t2
| Tdata(id, li) -> id ^ List.fold_left (fun s t -> s ^ " " ^ string_of_typ t) "" li
| Tproduct(t1, t2) -> string_of_typ t1 ^ " * " ^ string_of_typ t2
| Tvar(v) -> match v.def with
    | None -> "Var " ^ string_of_int v.id
    | Some t -> "(Var " ^ string_of_int v.id ^ " = " ^ string_of_typ t ^ ")"

let rec string_of_typ_shovars typ = match typ with
| Tint -> "Int"
| Tbool -> "Bool"
| Tstring -> "String"
| Tunit -> "Unit"
| Tdata(id, li) -> id ^ List.fold_left (fun s t -> s ^ " " ^ string_of_typ_shovars t) "" li
| Tarrow(li, t2) -> List.fold_left (fun s t -> s ^ string_of_typ_shovars t ^ " -> ") "" li ^ string_of_typ_shovars t2
| Tproduct(t1, t2) -> string_of_typ_shovars t1 ^ " * " ^ string_of_typ_shovars t2
| Tvar(v) -> match v.def with
    | None -> "Var " ^ string_of_int v.id
    | Some t -> "(Var " ^ string_of_int v.id ^ " = " ^ string_of_typ_shovars t ^ ")"

