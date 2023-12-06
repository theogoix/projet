
(* The type of tokens. *)

type token = 
  | WHERE
  | UIDENT of (string)
  | TRUE
  | THEN
  | STRING of (string)
  | SEMICOL
  | PLUS
  | OR
  | OPAR
  | OF
  | OBRAC
  | NEQ
  | MUL
  | MODULE
  | MINUS
  | LT
  | LIDENT of (string)
  | LET
  | LE
  | INT of (int)
  | INSTANCE
  | IN
  | IMPORT
  | IF
  | GT
  | GE
  | FORALL
  | FALSE
  | EQUAL
  | EOF
  | ELSE
  | EFFECT_DOT_CONSOLE
  | DOUBLEEQ
  | DOUBLECOL
  | DOUBLEARROW
  | DOT
  | DO
  | DIV
  | DATA
  | CPAR
  | CONC
  | COMMA
  | CLASS
  | CBRAC
  | CASE
  | BAR
  | ARROW
  | AND

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val file: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (Ast.decl list)
