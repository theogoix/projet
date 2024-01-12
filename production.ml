
(* Main file *)

open Ast
open Typing
open Grouping
open Format
open Lexing
open Indentlexer
open Errors
open X86_64


let align_stack = 
  (movq (imm 8) !%rdx ++
  notq !%rdx ++
  andq !%rdx !%rsp);;


let if_counter = ref 0;;
let str_counter = ref 0;; (* strings dans le segment de données*)
let switch_counter = ref 0;;

let data = ref (label ".Sprint_int" ++
                string "%d\n" ++
                label ".Sprint_str" ++
                string "%s\n");;

let get_if_labels () =
  incr if_counter;
  "IF_" ^ string_of_int !if_counter,
  "ENDIF_" ^ string_of_int !if_counter;;

let get_str_label () =
  incr str_counter;
  ".STR_" ^ string_of_int !str_counter;;

let get_switch_labels n =
  incr switch_counter;
  List.init n (fun i -> "SWITCH_" ^ string_of_int !switch_counter ^ "_" ^ string_of_int i),
  "ENDSWITCH_" ^ string_of_int !switch_counter;;


(* Le code d'une expression doit renvoyer son résultat dans %rax *)
let rec compile_expr t_expr = match t_expr.expr_desc with
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
    compile_expr e1 ++
    pushq !%rax ++
    compile_expr e2 ++
    popq rbx ++
    begin match op with
      | Add -> addq !%rbx !%rax
      | Sub -> subq !%rax !%rbx ++
               movq !%rbx !%rax
      | Mul -> imulq !%rbx !%rax
      | Eq -> xorq !%rcx !%rcx ++ (* = entre strings géré dans la fonction StrEq*)
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
        compile_expr e ++
        movq !%rax (ind ~ofs:loc rbp)
    end
    nop (List.rev bind_li))
    in
    text ++
    compile_expr e
  | TEdo(expr_li) ->
    List.fold_left
    begin fun text e ->
      compile_expr e ++
      text
    end
    nop expr_li
  | TEif(e1, e2, e3) ->
    let lab1, lab2 = get_if_labels () in
    compile_expr e1 ++
    testq !%rax !%rax ++
    je lab1 ++
    compile_expr e2 ++
    jmp lab2 ++
    label lab1 ++
    compile_expr e3 ++
    label lab2
  | TEswitch(e, branch_li, default_loc, default_e) ->
    let lab_li, lab_end = get_switch_labels (List.length branch_li) in
    compile_expr e ++

    begin List.fold_left2
    ( fun text branch lab ->
      let c, e_branch = branch in
      cmpq (imm c) !%rax ++
      jne lab ++

      compile_expr e_branch ++
      jmp lab_end ++

      label lab++


      text 
    )
    nop branch_li lab_li end ++

    (* default *)
    begin match default_loc with
      | Some loc -> movq !%rax (ind ~ofs:loc rbp)
      | None -> nop end ++
    compile_expr default_e ++

    label lab_end

  | TEcase(li, branches) ->
    begin match branches with 
      | (_, e) :: [] -> compile_expr e
      | _ -> nop
    end
  | TEappli(label, expr_li) ->
    (List.fold_left
    begin fun text e ->
      compile_expr e ++
      pushq !%rax ++
      text
    end
    nop expr_li) ++
    call label ++
    addq (imm (8*List.length expr_li)) !%rsp
  | _ -> nop


let compile_fun f = 
  let (id, n_arg, n_alloc, e) = f in
  label id ++
  pushq !%rbp ++
  movq !%rsp !%rbp ++
  subq (imm (8*n_alloc)) !%rsp ++
  compile_expr e ++
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
        align_stack ++
        movq (ind ~ofs:16 rbp) !%rsi ++
        movq (ilab ".Sprint_int") !%rdi ++
        movq (imm 0) !%rax ++
        call "printf" ++
        leave ++
        ret ++


        label "print_bool" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        align_stack ++
        movq (ind ~ofs:16 rbp) !%rsi ++
        movq (ilab ".Sprint_int") !%rdi ++
        movq (imm 0) !%rax ++
        call "printf" ++
        leave ++
        ret ++


        label "log" ++

        pushq !%rbp ++
        movq !%rsp !%rbp ++

        align_stack ++

        movq (ind ~ofs:16 rbp) !%rsi ++
        movq (ilab ".Sprint_str") !%rdi ++
        call "printf" ++

        movq (imm 0) !%rax ++
        
        leave ++
        ret ++


        label "not" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        movq (ind ~ofs:16 rbp) !%rbx ++
        movq (imm 1) !%rax ++
        subq !%rbx !%rax ++
        leave ++
        ret ++


        label "Concat" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        align_stack ++

        movq (ind ~ofs:16 rbp) !%rdi ++ (*calcul de la mémoire requise*)
        call "strlen" ++
        movq !%rax !%r12 ++
        movq !%rax !%r13 ++
        movq (ind ~ofs:24 rbp) !%rdi ++
        call "strlen" ++
        addq !%rax !%r12 ++
        incq !%r12 ++

        movq !%r12 !%rdi ++ (*allocation*)
        call "malloc" ++
        movq !%rax !%rbx ++

        movq !%rbx !%rdi ++
        movq (ind ~ofs:16 rbp) !%rsi ++
        call "strcpy" ++

        movq !%rbx !%rdi ++
        addq !%r13 !%rdi ++
        movq (ind ~ofs:24 rbp) !%rsi ++
        call "strcpy" ++

        movq !%rbx !%rax ++

        leave ++
        ret ++


        (* label "len" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        align_stack ++

        movq (ind ~ofs:16 rbp) !%rdi ++
        call "strlen" ++

        leave ++
        ret ++ *)


        label "StrEq" ++
        pushq !%rbp ++
        movq !%rsp !%rbp ++
        align_stack ++

        movq (ind ~ofs:16 rbp) !%rdi ++
        movq !%rdi !%rbx ++
        call "strlen" ++
        movq !%rax !%r12 ++

        movq (ind ~ofs:24 rbp) !%rdi ++
        movq !%rdi !%rcx ++
        call "strlen" ++

        cmpq !%r12 !%rax ++ (*même longeur*)
        jne "StrEq_No" ++

        label "StrEq_Loop" ++

        movb (ind rbx) !%al ++
        cmpb !%al (ind rcx) ++
        jne "StrEq_No" ++

        incq !%rbx ++
        incq !%rcx ++

        cmpb (imm 0) (ind rbx) ++

        jne "StrEq_Loop" ++

        movq (imm 1) !%rax ++
        leave ++
        ret ++

        label "StrEq_No" ++
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
