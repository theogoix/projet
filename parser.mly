
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
  | DATA ; id = UIDENT ; vars = LIDENT* ; EQUAL ; li = separated_nonempty_list(BAR, consdecl) { {decl_desc = DefData(id, vars, li) ; loc = ($startpos, $endpos)} }
  | CLASS ; UIDENT ; LIDENT* ; WHERE ; OBRAC ; separated_list(SEMICOL, tdecl) ; CBRAC { {decl_desc = DefClass ; loc = ($startpos, $endpos)} }
  | INSTANCE ; instance ; WHERE ; OBRAC ; separated_list(SEMICOL, defn) ;  CBRAC { {decl_desc = DefInstance ; loc = ($startpos, $endpos)} }
;

consdecl:
  id = UIDENT ; li = atype* { (id, li) }
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
  | TRUE { Cbool(true) }
  | FALSE { Cbool(false) }
  | n = INT { Cint(n) }
  | str = STRING { Cstring(str) }
;

atom:
  | c = constant { {expr_desc = Ecst(c) ; loc = ($startpos, $endpos)} }
  | id = LIDENT { {expr_desc = Evar(id) ; loc = ($startpos, $endpos)} }
  | s = UIDENT { {expr_desc = Econstr(s, [])  ; loc = ($startpos, $endpos)}}
  | OPAR ; e = expr ; CPAR { e }
  | OPAR ; e = expr ; DOUBLECOL ; t = btype ; CPAR { {expr_desc = Eforcetype(e, t) ; loc = ($startpos, $endpos)} }
;

expr:
  | a = atom { a }
  | MINUS ; e = expr { 
    {expr_desc = Ebinop(Sub, {expr_desc = Ecst(Cint(0)) ; loc = ($startpos, $endpos)}, e) ; loc = ($startpos, $endpos)} }
  | e1 = expr ; b = binop ; e2 = expr { {expr_desc = Ebinop(b, e1, e2) ; loc = ($startpos, $endpos)} }
  | s = LIDENT ; li = atom+ { {expr_desc = Eappli(s, li) ; loc = ($startpos, $endpos)} }
  | s = UIDENT ; li = atom+ { {expr_desc = Econstr(s, li) ; loc = ($startpos, $endpos)} }
  | IF ; ec = expr ; THEN ; e1 = expr ; ELSE ; e2 = expr { {expr_desc = Eif(ec, e1, e2) ; loc = ($startpos, $endpos)} }
  | DO ; OBRAC ; li = separated_nonempty_list(SEMICOL, expr) ; CBRAC { {expr_desc = Edo(li) ; loc = ($startpos, $endpos)} }
  | LET ; OBRAC ; bs = separated_nonempty_list(SEMICOL, binding) ; CBRAC ; IN ; e = expr { {expr_desc = Elet(bs, e) ; loc = ($startpos, $endpos)} }
  | CASE ; e = expr ; OF ; OBRAC ; li = separated_nonempty_list(SEMICOL, branch) ; CBRAC { {expr_desc = Ecase([e], li) ; loc = ($startpos, $endpos)} }
;

binding:
  id = LIDENT ; EQUAL ; e = expr { (id, e) }
;

branch:
  p = pattern ; ARROW ; e = expr { ([p], e) }
;

%inline binop:
  | DOUBLEEQ { Eq }
  | NEQ { Neq }
  | LT { Lt }
  | LE { Le }
  | GT { Gt }
  | GE { Ge }
  | PLUS { Add }
  | MINUS { Sub }
  | MUL { Mul }
  | DIV { Div }
  | CONC { Conc }
  | AND { And }
  | OR { Or }
;
