
/* Analyseur syntaxique pour petit Purescript */

%{
  open Ast

%}

/* Déclaration des tokens */

%token EOF
%token MODULE WHERE
%token EFFECT_DOT_CONSOLE
%token OBRAC CBRAC
%token OPAR CPAR
%token BAR
%token IMPORT
%token DOT SEMICOL DOUBLECOL COMMA
%token DATA CLASS INSTANCE FORALL
%token EQUAL
%token IF THEN ELSE DO LET IN CASE OF
%token TRUE FALSE
%token ARROW DOUBLEARROW
%token DOUBLEEQ NEQ LT LE GT GE PLUS MINUS MUL DIV CONC AND OR
%token <int> INT
%token <string> STRING
%token <string> LIDENT
%token <string> UIDENT


/* Priorités et associativités des tokens */

%nonassoc IN ELSE
%left OR
%left AND
%nonassoc DOUBLEEQ NEQ GT GE LT LE
%left PLUS MINUS CONC
%left MUL DIV


%start file


%type <Ast.decl list> file

%%





file:
  MODULE ; UIDENT ; WHERE ; OBRAC ; imports ; decl_li = separated_list(SEMICOL, decl) ; CBRAC ; EOF
    { decl_li }
;

imports:
  IMPORT ; UIDENT ; SEMICOL ; IMPORT ; UIDENT ; SEMICOL ; IMPORT ; EFFECT_DOT_CONSOLE; SEMICOL { () }
;

decl:
  | d = defn { d }
  | d = tdecl { d } 
  | DATA ; UIDENT ; LIDENT* ; EQUAL ; separated_nonempty_list(BAR, consdecl) { {decl_desc = DefData ; loc = ($startpos, $endpos)} }
  | CLASS ; UIDENT ; LIDENT* ; WHERE ; OBRAC ; separated_list(SEMICOL, tdecl) ; CBRAC { {decl_desc = DefClass ; loc = ($startpos, $endpos)} }
  | INSTANCE ; instance ; WHERE ; OBRAC ; separated_list(SEMICOL, defn) ;  CBRAC { {decl_desc = DefInstance ; loc = ($startpos, $endpos)} }
;

consdecl:
  UIDENT ; atype* { () }
;

defn:
  id = LIDENT ; li = patarg* ; EQUAL ; e = expr { {decl_desc = DefEqfun(id, li, e) ; loc = ($startpos, $endpos)} }
;

tdecl:
  | id = LIDENT ; DOUBLECOL ; forall = forall ; types = typeargs { let insts, args, ret = types in {decl_desc = DefTypefun(id, forall, insts, args, ret) ; loc = ($startpos, $endpos)} }
;

typeargs:
  | inst = ntype ; DOUBLEARROW ; types = typeargs { let insts, args, ret = types in inst::insts, args, ret }
  | t = btype ; ARROW ; types = typeargs_2 { let insts, args, ret = types in insts, t::args, ret }
  | t = btype { ([], [], t) }
;
typeargs_2: // once a -> has been read, no more =>
  | t = btype ; ARROW ; types = typeargs_2 { let insts, args, ret = types in insts, t::args, ret }
  | t = btype { ([], [], t) }
;

forall:
  | FORALL ; li = LIDENT+ ; DOT { li }
  |   { [] }
;

ntype:
  s = UIDENT ; li = atype* { (*TypeConstr(s, li)*)() }
;

atype:
  | s = LIDENT { {tpe_desc = TypeVar(s) ; loc = ($startpos, $endpos)} }
  | s = UIDENT { {tpe_desc = TypeConstr(s, []) ; loc = ($startpos, $endpos)} }
  | OPAR ; t = btype ; CPAR { t }
;

btype:
  | s = UIDENT ; li = atype+ { {tpe_desc = TypeConstr(s, li) ; loc = ($startpos, $endpos)} } 
  | t = atype { t }
;

instance:
  | ntype { () }
  | ntype ; DOUBLEARROW ; ntype { () }
  | OPAR ; separated_nonempty_list(COMMA, ntype) ; CPAR ; DOUBLEARROW ; ntype { () }
;

patarg:
  | c = constant { {pattern_desc = PatConstant(c) ; loc = ($startpos, $endpos)} }
  | s = LIDENT { {pattern_desc = PatVar(s) ; loc = ($startpos, $endpos)} }
  | s = UIDENT { {pattern_desc = PatConstructor(s, []) ; loc = ($startpos, $endpos)} }
  | OPAR ; p = pattern ; CPAR { p }
;

pattern:
  | p = patarg { p }
  | s = UIDENT ; li = patarg+ { {pattern_desc = PatConstructor(s, li) ; loc = ($startpos, $endpos)} }
;

constant:
  | TRUE { {constant_desc = Cbool(true) ; loc = ($startpos, $endpos)} }
  | FALSE { {constant_desc = Cbool(false) ; loc = ($startpos, $endpos)} }
  | n = INT { {constant_desc = Cint(n) ; loc = ($startpos, $endpos)} }
  | str = STRING { {constant_desc = Cstring(str) ; loc = ($startpos, $endpos)} }
;

atom:
  | c = constant { {expr_desc = Ecst(c) ; loc = ($startpos, $endpos)} }
  | id = LIDENT { {expr_desc = Evar(id) ; loc = ($startpos, $endpos)} }
  | s = UIDENT { {expr_desc = Econstr(s, [])  ; loc = ($startpos, $endpos)}}
  | OPAR ; e = expr ; CPAR { e }
  | OPAR ; e = expr ; DOUBLECOL ; btype ; CPAR { e }
;

expr:
  | a = atom { a }
  | MINUS ; e = expr { 
    {expr_desc = Ebinop(
      {binop_desc = Sub ; loc = ($startpos, $endpos)},
      {expr_desc = Ecst({constant_desc = Cint(0) ; loc = ($startpos, $endpos)}) ; loc = ($startpos, $endpos)},
      e
    ) ;
    loc = ($startpos, $endpos)} }
  | e1 = expr ; b = binop ; e2 = expr { {expr_desc = Ebinop(b, e1, e2) ; loc = ($startpos, $endpos)} }
  | s = LIDENT ; li = atom+ { {expr_desc = Eappli(s, li) ; loc = ($startpos, $endpos)} }
  | s = UIDENT ; li = atom+ { {expr_desc = Econstr(s, li) ; loc = ($startpos, $endpos)} }
  | IF ; ec = expr ; THEN ; e1 = expr ; ELSE ; e2 = expr { {expr_desc = Eif(ec, e1, e2) ; loc = ($startpos, $endpos)} }
  | DO ; OBRAC ; li = separated_nonempty_list(SEMICOL, expr) ; CBRAC { {expr_desc = Edo(li) ; loc = ($startpos, $endpos)} }
  | LET ; OBRAC ; bs = separated_nonempty_list(SEMICOL, binding) ; CBRAC ; IN ; e = expr { {expr_desc = Elet(bs, e) ; loc = ($startpos, $endpos)} }
  | CASE ; e = expr ; OF ; OBRAC ; li = separated_nonempty_list(SEMICOL, branch) ; CBRAC { {expr_desc = Ecase(e, li) ; loc = ($startpos, $endpos)} }
;

binding:
  id = LIDENT ; EQUAL ; e = expr { (id, e) }
;

branch:
  p = pattern ; ARROW ; e = expr { (p, e) }
;

%inline binop:
  | DOUBLEEQ { {binop_desc = Eq ; loc = ($startpos, $endpos)} }
  | NEQ { {binop_desc = Neq ; loc = ($startpos, $endpos)} }
  | LT { {binop_desc = Lt ; loc = ($startpos, $endpos)} }
  | LE { {binop_desc = Le ; loc = ($startpos, $endpos)} }
  | GT { {binop_desc = Gt ; loc = ($startpos, $endpos)} }
  | GE { {binop_desc = Ge ; loc = ($startpos, $endpos)} }
  | PLUS { {binop_desc = Add ; loc = ($startpos, $endpos)} }
  | MINUS { {binop_desc = Sub ; loc = ($startpos, $endpos)} }
  | MUL { {binop_desc = Mul ; loc = ($startpos, $endpos)} }
  | DIV { {binop_desc = Div ; loc = ($startpos, $endpos)} }
  | CONC { {binop_desc = Conc ; loc = ($startpos, $endpos)} }
  | AND { {binop_desc = And ; loc = ($startpos, $endpos)} }
  | OR { {binop_desc = Or ; loc = ($startpos, $endpos)} }
;
