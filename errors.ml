
(* Main file *)

open Ast
open Format
open Lexing


let ifile = ref ""



(* error localisation *)
let localisation pos =
  let pos1, pos2 = pos in
  let l1 = pos1.pos_lnum in
  let c1 = pos1.pos_cnum - pos2.pos_bol in
  let l2 = pos2.pos_lnum in
  let c2 = pos2.pos_cnum - pos2.pos_bol in
  if l1 == l2 then
    eprintf "File \"%s\", line %d, characters %d-%d:\n" !ifile l1 c1 c2
  else
    eprintf "File \"%s\", lines %d-%d, characters %d-%d:\n" !ifile l1 l2 c1 c2
