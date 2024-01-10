
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
let rec compile_expr t_expr aligned = match t_expr.expr_desc with
  | TEcst c ->  
    begin match c with
      | Cint n -> movq (imm n) !%rax
      | Cbool b -> movq (imm (if b then 1 else 0)) !%rax
      | _ -> nop
    end
  | TEvar loc ->
    movq (ind ~ofs:loc rbp) !%rax
  | TEbinop(op,e1,e2) -> 
    compile_expr e1 aligned ++
    pushq !%rax ++
    compile_expr e2 (not aligned) ++
    popq rbx ++
    begin match op with
      | Add -> addq !%rbx !%rax
      | Sub -> subq !%rax !%rbx ++ movq !%rbx !%rax
      | Mul -> imulq !%rbx !%rax
      | _ -> nop
    end
  | TElet(bind_li,e) ->
    let text, aligned = (List.fold_left
    begin fun acc bind ->
      let text, aligned = acc in
      let loc, e = bind in
        (text ++
        compile_expr e aligned ++
        movq !%rax (ind ~ofs:loc rbp),
        not aligned)
    end
    (nop, aligned) (List.rev bind_li))
    in
    text ++
    compile_expr e aligned
  | TEcase(li, branches) ->
    begin match branches with 
      | (_, e) :: [] -> compile_expr e aligned
      | _ -> nop
    end
  | TEappli(label, expr_li) ->
    (if not aligned then subq (imm 8) !%rsp else nop) ++
    (List.fold_left
    begin fun text e ->
      text ++
      compile_expr e aligned ++
      pushq !%rax
    end
    nop expr_li) ++
    call label ++
    addq (imm (8*List.length expr_li)) !%rsp ++
    (if not aligned then addq (imm 8) !%rsp else nop)
  | _ -> nop


let compile_fun f = 
  let (id, n_arg, n_alloc, e) = f in
  label id ++
  pushq !%rbp ++
  movq !%rsp !%rbp ++
  subq (imm (8*n_alloc)) !%rsp ++
  compile_expr e false ++
  leave ++
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
        globl "main" ++
        (*label "main" ++
        movq !%rsp !%rbp ++
        code ++
        movq (imm 0) !%rax ++ (* exit *)
        ret ++*)


        label "print_int" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        movq (ind ~ofs:16 rbp) !%rsi ++
        movq (ilab ".Sprint_int") !%rdi ++
        movq (imm 0) !%rax ++
        call "printf" ++
        leave ++
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
