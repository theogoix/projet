
(* Main file *)

open Ast
open Typing
open Grouping
open Format
open Lexing
open Indentlexer
open Errors
open X86_64



(* Le code d'une expression doit renvoyer son résultat dans %rax *)
let rec compile_expr t_expr = match t_expr.expr_desc with
  | TEcst c ->  
    begin match c with
      | Cint n -> movq (imm n) !%rax
      | Cbool b -> movq (imm (if b then 1 else 0)) !%rax
      | _ -> nop
    end
  | TEbinop(op,e1,e2) -> 
    compile_expr e1 ++
    pushq !%rax ++
    compile_expr e2 ++
    popq rbx ++
    begin match op with
      | Add -> addq !%rbx !%rax
      | Sub -> subq !%rbx !%rax
      | Mul -> imulq !%rbx !%rax
      | _ -> nop
    end
  | TEcase(li, branches) ->
    begin match branches with 
      | (_, e) :: [] -> compile_expr e
      | _ -> nop
    end
  | _ -> nop


let compile_fun f = 
  let (id, n_arg, e) = f in
  label id ++
  compile_expr e ++
  ret


let compile_program program ofile =
  (*let p = alloc p in
  Format.eprintf "%a@." print p;
  let codefun, code = List.fold_left compile_stmt (nop, nop) p in*)
  let codefun = List.fold_left 
    (fun acc f -> acc ++ compile_fun f)
    nop program 
  in
  let p =
    { text =
        globl "main" ++ label "main" ++
        movq !%rsp !%rbp ++
        (*code ++*)
        movq (imm 0) !%rax ++ (* exit *)
        ret ++
        label "print_int" ++
        movq !%rdi !%rsi ++
        movq (ilab ".Sprint_int") !%rdi ++
        movq (imm 0) !%rax ++
        call "printf" ++
        ret ++
        codefun;
      data = label ".Sprint_int" ++ string "%d\n"
        (*Hashtbl.fold (fun x _ l -> label x ++ dquad [1] ++ l) genv
          (label ".Sprint_int" ++ string "%d\n")*)
    }
  in
  let f = open_out ofile in
  let fmt = formatter_of_out_channel f in
  X86_64.print_program fmt p;
  fprintf fmt "@?";
  close_out f
