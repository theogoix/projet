
(* Main file *)

open Ast
open Typing
open Grouping
open Format
open Lexing
open Indentlexer
open Errors


(* name of the file to compile *)
let ifile = ref ""



let set_file f s = f := s

(* Compiler options *)
let parse_only = ref false
let type_only = ref false

let options =
  ["--parse-only", Arg.Set parse_only,
  "  Compiler will stop at syntax analysis" ;
  "--type-only", Arg.Set type_only,
   "  Compiler will stop at type analysis"]

let usage = "usage: ppurs [option] file.purs"







(* error localisation *)
(*let localisation pos =
  let l = pos.pos_lnum in
  let c = pos.pos_cnum - pos.pos_bol + 1 in
  eprintf "File \"%s\", line %d, characters %d-%d:\n" !ifile l (c-1) c *)


(* Main part*)
let () =

  (* Parsing de la ligne de commande *)
  Arg.parse options (set_file ifile) usage;
  
  if !ifile="" then begin eprintf "No file to compile\n@?"; exit 1 end;

  Errors.ifile := !ifile;
  
  if not (Filename.check_suffix !ifile ".purs") then begin
    eprintf "Entry file must have .purs extension\n@?";
    Arg.usage options usage;
    exit 3
  end;

  
  let f = open_in !ifile in

  
  let buf = Lexing.from_channel f in

  try
    (* Parsing: la fonction  Parser.prog transforme le tampon lexical en un
       arbre de syntaxe abstraite si aucune erreur (lexicale ou syntaxique)
       n'est détectée.
       La fonction Lexer.token est utilisée par Parser.prog pour obtenir
       le prochain token. *)
    let decl_li = Parser.file Indentlexer.token buf in
    close_in f;

    (* End of parsing *)

    print_endline "Successful parsing";

    if !parse_only then exit 0;

    (* type analysis *)

    let gdecl_li = group_fun decl_li in ();

    type_file gdecl_li;

    print_endline "Successful typing";

    exit 0

  with
    | Lexer.Lexing_error c ->
	localisation (Lexing.lexeme_start_p buf, Lexing.lexeme_end_p buf);
	eprintf "Lexing error: %s@." c;
	exit 1

    | Parser.Error ->
	localisation (Lexing.lexeme_start_p buf, Lexing.lexeme_end_p buf);
	eprintf "Syntax error@.";
	exit 1

