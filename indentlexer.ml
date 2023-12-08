
open Lexing
open Parser

let token_to_str : token -> string =
  fun _tok ->
    match _tok with
    | AND ->
        "AND"
    | ARROW ->
        "ARROW"
    | BAR ->
        "BAR"
    | CASE ->
        "CASE"
    | CBRAC ->
        "}"
    | CLASS ->
        "CLASS"
    | COMMA ->
        "COMMA"
    | CONC ->
        "CONC"
    | CPAR ->
        ")"
    | DATA ->
        "DATA"
    | DIV ->
        "DIV"
    | DO ->
        "DO"
    | DOT ->
        "DOT"
    | DOUBLEARROW ->
        "DOUBLEARROW"
    | DOUBLECOL ->
        "DOUBLECOL"
    | DOUBLEEQ ->
        "DOUBLEEQ"
    | ELSE ->
        "ELSE"
    | EOF ->
        "EOF"
    | EQUAL ->
        "EQUAL"
    | FALSE ->
        "FALSE"
    | FORALL ->
        "FORALL"
    | GE ->
        "GE"
    | GT ->
        "GT"
    | IF ->
        "IF"
    | IMPORT ->
        "IMPORT"
    | IN ->
        "IN"
    | INSTANCE ->
        "INSTANCE"
    | INT n ->
        "INT " ^ string_of_int n
    | LE ->
        "LE"
    | LET ->
        "LET"
    | LIDENT s ->
        "LIDENT " ^ s
    | LT ->
        "LT"
    | MINUS ->
        "MINUS"
    | MODULE ->
        "MODULE"
    | MUL ->
        "MUL"
    | NEQ ->
        "NEQ"
    | OBRAC ->
        "{"
    | OF ->
        "OF"
    | OPAR ->
        "("
    | OR ->
        "OR"
    | PLUS ->
        "PLUS"
    | SEMICOL ->
        ";"
    | STRING s ->
        "STRING " ^s
    | THEN ->
        "THEN"
    | TRUE ->
        "TRUE"
    | UIDENT s ->
        "UIDENT " ^s
    | WHERE ->
        "WHERE"
    | EFFECT_DOT_CONSOLE ->
      "EFFECT_DOT_CONSOLE"
    (*| _ ->
      "?"*)

(* tokens to send*)
let token_queue = Queue.create ()

type indic = B of int | M
let ind_stack = Stack.create ()

let emmit tok = Queue.add tok token_queue

let rec close c = 
  match Stack.top_opt ind_stack with 
    | Some M -> ()
    | Some B(n) -> 
      if n > c then 
        let _ = Stack.pop ind_stack in emmit CBRAC; close c
      else if n = c then
        emmit SEMICOL
      else () 
    | None -> ()


let rec depile_M () = 
  match Stack.pop_opt ind_stack with 
    | Some M -> ()
    | Some B(n) -> emmit CBRAC; depile_M ()
    | None -> ()



let rec find_tokens tok pos c buf weak = 
  match tok with 
    | IF | OPAR | CASE -> if not weak then close c else (); Stack.push M ind_stack ; emmit tok
    | CPAR | ELSE | IN -> depile_M () ; emmit tok
    | THEN -> depile_M () ; Stack.push M ind_stack ; emmit tok
    | WHERE | DO | LET | OF -> 
      if not weak then close c else ();
        if tok = LET then
          Stack.push M ind_stack
        else if tok = OF then
          depile_M ()
        else () ; 
        emmit tok ;
        emmit OBRAC ; 
        let tok' = Lexer.token buf in
        let pos' = Lexing.lexeme_start_p buf in
        let c' = pos'.pos_cnum - pos'.pos_bol + 1 in
        if not weak then close c' else ();
        Stack.push (B c') ind_stack ;
        find_tokens tok' pos' c' buf true
    | EOF -> if not weak then close (-1) else (); emmit tok
    | _ -> if not weak then close c else (); emmit tok


(* token buf  returns the next token, computing it if needed (ie if token_queue is empty) *)
let token buf = 
  if Queue.is_empty token_queue then
    let tok = Lexer.token buf in
    let pos = Lexing.lexeme_start_p buf in
    let c = pos.pos_cnum - pos.pos_bol + 1 in
    find_tokens tok pos c buf false
  else () ;
  let tok = Queue.take token_queue in
  (*print_endline (token_to_str tok);*)  (*for debbuging*)
  tok