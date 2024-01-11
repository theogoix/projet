
(* Main file *)

open Ast
open Typing
open Grouping
open Format
open Lexing
open Indentlexer
open Errors
open X86_64

let if_counter = ref 0;;
let str_counter = ref 0;; (* strings dans le segment de données*)

let data = ref (label ".Sprint_int" ++
                string "%d\n" ++
                label ".Sprint_str" ++
                string "%s\n");;

let get_if_label () =
  incr if_counter;
  "IF_" ^ string_of_int !if_counter,
  "ENDIF_" ^ string_of_int !if_counter;;

let get_str_label () =
  incr str_counter;
  ".STR_" ^ string_of_int !str_counter;;


(* Le code d'une expression doit renvoyer son résultat dans %rax *)
let rec compile_expr t_expr aligned = match t_expr.expr_desc with
  | TEcst c ->  
    begin match c with
      | Cint n -> movq (imm n) !%rax
      | Cbool b -> movq (imm (if b then 1 else 0)) !%rax
      | Cstring s ->
        let lab = get_str_label () in
        data := !data ++
                label lab ++
                string s;
        movq (ilab lab) !%rax
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
      | Sub -> subq !%rax !%rbx ++
               movq !%rbx !%rax
      | Mul -> imulq !%rbx !%rax
      | Eq -> xorq !%rcx !%rcx ++ (* TODO: Faire marcher le Eq pour les strings *)
              cmpq !%rax !%rbx ++
              sete !%cl ++
              movq !%rcx !%rax
      | Neq -> xorq !%rcx !%rcx ++
               cmpq !%rax !%rbx ++
               setne !%cl ++
               movq !%rcx !%rax
      | Ge -> xorq !%rcx !%rcx ++
              cmpq !%rax !%rbx ++
              setge !%cl ++
              movq !%rcx !%rax
      | Gt -> xorq !%rcx !%rcx ++
              cmpq !%rax !%rbx ++
              setg !%cl ++
              movq !%rcx !%rax
      | Le -> xorq !%rcx !%rcx ++
              cmpq !%rax !%rbx ++
              setle !%cl ++
              movq !%rcx !%rax
      | Lt -> xorq !%rcx !%rcx ++
              cmpq !%rax !%rbx ++
              setl !%cl ++
              movq !%rcx !%rax
      | And -> andq !%rbx !%rax
      | Or -> orq !%rbx !%rax
      | _ -> nop
    end
  | TElet(bind_li,e) ->
    let text = (List.fold_left
    begin fun text bind ->
      let loc, e = bind in
        text ++
        compile_expr e aligned ++
        movq !%rax (ind ~ofs:loc rbp)
    end
    nop (List.rev bind_li))
    in
    text ++
    compile_expr e aligned
  | TEdo(expr_li) ->
    List.fold_left
    begin fun text e ->
      compile_expr e aligned ++
      text
    end
    nop expr_li
  | TEif(e1, e2, e3) ->
    let lab1, lab2 = get_if_label () in
    compile_expr e1 aligned ++
    testq !%rax !%rax ++
    je lab1 ++
    compile_expr e2 aligned ++
    jmp lab2 ++
    label lab1 ++
    compile_expr e3 aligned ++
    label lab2
  | TEcase(li, branches) ->
    begin match branches with 
      | (_, e) :: [] -> compile_expr e aligned
      | _ -> nop
    end
  | TEappli(label, expr_li) ->
    (if aligned != ((List.length expr_li) mod 2 = 0) then subq (imm 8) !%rsp else nop) ++
    let temp_aligned = ref ((List.length expr_li) mod 2 = 0) in
    (List.fold_left
    begin fun text e ->
      temp_aligned := not !temp_aligned;
      text ++
      compile_expr e (not !temp_aligned) ++
      pushq !%rax
    end
    nop expr_li) ++
    call label ++
    addq (imm (8*List.length expr_li)) !%rsp ++
    (if aligned != ((List.length expr_li) mod 2 = 0) then addq (imm 8) !%rsp else nop)
  | _ -> nop


let compile_fun f = 
  let (id, n_arg, n_alloc, e) = f in
  label id ++
  pushq !%rbp ++
  movq !%rsp !%rbp ++
  subq (imm (8*n_alloc)) !%rsp ++
  compile_expr e (n_alloc mod 2 = 0) ++
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


        label "print_bool" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        movq (ind ~ofs:16 rbp) !%rsi ++
        movq (ilab ".Sprint_int") !%rdi ++
        movq (imm 0) !%rax ++
        call "printf" ++
        leave ++
        ret ++

        label "log" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        movq (ind ~ofs:16 rbp) !%rsi ++
        movq (ilab ".Sprint_str") !%rdi ++
        call "printf" ++
        movq (imm 0) !%rax ++
        leave ++
        ret ++

        codefun;
        
      data = !data
    }
  in
  let f = open_out ofile in
  let fmt = formatter_of_out_channel f in
  X86_64.print_program fmt p;
  fprintf fmt "@?";
  close_out f
