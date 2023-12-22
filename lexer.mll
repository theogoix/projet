
(* Analyseur lexical pour petit Purescript *)

{
  open Lexing
  open Parser

  (* exception à lever pour signaler une erreur lexicale *)
  exception Lexing_error of string

  (* note : penser à appeler la fonction Lexing.new_line
     à chaque retour chariot (caractère '\n') *)
  
  

  let string_buffer = Buffer.create 1024
  
  let id_or_kwd =
    let h = Hashtbl.create 32 in
    List.iter (fun (s, tok) -> Hashtbl.add h s tok)
      ["case", CASE ;
       "class", CLASS ;
       "data", DATA ;
       "do", DO ;
       "else", ELSE ;
       "false", FALSE ;
       "forall", FORALL ;
       "if", IF ;
       "import", IMPORT ;
       "in", IN ;
       "instance", INSTANCE ;
       "let", LET ;
       "module", MODULE ;
       "of", OF ;
       "then", THEN ;
       "true", TRUE ;
       "where", WHERE
       ];
   fun s upper -> try Hashtbl.find h s with Not_found -> if upper then UIDENT s else LIDENT s
  

  (*let (string_start:Lexing.position ref) = ref {
    pos_fname = name;
    pos_lnum = 1;
    pos_bol = 0;
    pos_cnum = -1;
  };;*)

}

let digit = ['0'-'9']
let lowercase = ['a'-'z' '_']
let uppercase = ['A'-'Z']
let id_char = ['_' 'a'-'z' 'A'-'Z' '0'-'9' '\'']

rule token = parse
  | [' '  '\t']+ { token lexbuf }
  | '\n' { Lexing.new_line lexbuf ; token lexbuf}
  | "{-" { comment lexbuf }
  | "--" { line_comment lexbuf }
  | '+' { PLUS }
  | "->" { ARROW }
  | "=>" { DOUBLEARROW }
  | '-' { MINUS }
  | '*' { MUL }
  | '/' { DIV }
  | '=' { EQUAL }
  | "==" { DOUBLEEQ }
  | "/=" { NEQ }
  | "<" { LT }
  | "<=" { LE }
  | ">" { GT }
  | ">=" { GE }
  | "<>" { CONC }
  | "&&" { AND }
  | "||" { OR }
  | "|" { BAR }
 (* | '{' { OBRAC }  *)
 (* | '}' { CBRAC }  *)
  | '(' { OPAR }
  | ')' { CPAR }
  | ',' { COMMA }
 (* | ';' { SEMICOL }  *)
  | '.' { DOT }
  | "::" { DOUBLECOL }
  | "Effect.Console" { EFFECT_DOT_CONSOLE }
  | '"'     { let s = string lexbuf in STRING (s) }
  | ['1'-'9'] digit* as s { INT (int_of_string s) }
  | '0' { INT 0 }
  | lowercase id_char* as s { id_or_kwd s false}
  | uppercase id_char* as s { id_or_kwd s true}
  | eof { EOF }
  | _ { raise (Lexing_error "Unknown symbol") }

and string = parse
  | '"'
      { let s = Buffer.contents string_buffer in
	Buffer.reset string_buffer;
	s }
  | "\\\""
      { Buffer.add_char string_buffer '"'; string lexbuf }
  | "\\\\"
      { Buffer.add_char string_buffer '\\'; string lexbuf }
  | "\\n"
      { Buffer.add_char string_buffer '\\'; Buffer.add_char string_buffer 'n' ; string lexbuf }
  | "\\"
      { string_skipper lexbuf }
  | "\n"
      { raise (Lexing_error "Unterminated string") }
  | eof
      { raise (Lexing_error "Unterminated string") }
  | _ as c
      { Buffer.add_char string_buffer c; string lexbuf }

and string_skipper = parse
  | "\\" { string lexbuf }
  | [' '  '\t'] { string_skipper lexbuf }
  | '\n' { Lexing.new_line lexbuf; string_skipper lexbuf }
  | _ { raise (Lexing_error "Unknown escape character") }

and comment = parse
  | "-}" { token lexbuf }
  | eof  { raise (Lexing_error "Unterminated comment") }
  | _  { comment lexbuf }

and line_comment = parse
  | '\n' { Lexing.new_line lexbuf ; token lexbuf }
  | _  { line_comment lexbuf }
  | eof  { EOF }
