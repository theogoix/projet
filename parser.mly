
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
  | DATA ; UIDENT ; LIDENT* ; EQUAL ; separated_nonempty_list(BAR, consdecl) { DefData }
  | CLASS ; UIDENT ; LIDENT* ; WHERE ; OBRAC ; separated_list(SEMICOL, tdecl) ; CBRAC { DefClass }
  | INSTANCE ; instance ; WHERE ; OBRAC ; separated_list(SEMICOL, defn) ;  CBRAC { DefInstance }
;

consdecl:
  UIDENT ; atype* { () }
;

defn:
  id = LIDENT ; li = patarg* ; EQUAL ; e = expr { DefEqfun(id, li, e) }
;

tdecl:
  | id = LIDENT ; DOUBLECOL ; forall = forall ; types = typeargs { let insts, args, ret = types in DefTypefun(id, forall, insts, args, ret) }
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
  | s = LIDENT { TypeVar(s) }
  | s = UIDENT { TypeConstr(s, []) }
  | OPAR ; t = btype ; CPAR { t }
;

btype:
  | s = UIDENT ; li = atype+ { TypeConstr(s, li) } 
  | t = atype { t }
;

instance:
  | ntype { () }
  | ntype ; DOUBLEARROW ; ntype { () }
  | OPAR ; separated_nonempty_list(COMMA, ntype) ; CPAR ; DOUBLEARROW ; ntype { () }
;

patarg:
  | c = constant { PatConstant(c) }
  | s = LIDENT { PatVar(s) }
  | s = UIDENT { PatConstructor(s, []) }
  | OPAR ; p = pattern ; CPAR { p }
;

pattern:
  | p = patarg { p }
  | s = UIDENT ; li = patarg+ { PatConstructor(s, li) }
;

constant:
  | TRUE { Cbool(true) }
  | FALSE { Cbool(false) }
  | n = INT { Cint(n) }
  | str = STRING { Cstring(str) }
;

atom:
  | c = constant { Ecst(c) }
  | id = LIDENT { Evar(id) }
  | s = UIDENT { Econstr(s, []) }
  | OPAR ; e = expr ; CPAR { e }
  | OPAR ; e = expr ; DOUBLECOL ; btype ; CPAR { e }
;

expr:
  | a = atom { a }
  | MINUS ; e = expr { Ebinop(Sub, Ecst(Cint(0)), e) }
  | e1 = expr ; b = binop ; e2 = expr { Ebinop(b, e1, e2) }
  | s = LIDENT ; li = atom+ { Eappli(s, li) }
  | s = UIDENT ; li = atom+ { Econstr(s, li) }
  | IF ; ec = expr ; THEN ; e1 = expr ; ELSE ; e2 = expr { Eif(ec, e1, e2) }
  | DO ; OBRAC ; li = separated_nonempty_list(SEMICOL, expr) ; CBRAC { Edo(li) }
  | LET ; OBRAC ; bs = separated_nonempty_list(SEMICOL, binding) ; CBRAC ; IN ; e = expr { Elet(bs, e) }
  | CASE ; e = expr ; OF ; OBRAC ; li = separated_nonempty_list(SEMICOL, branch) ; CBRAC { Ecase(e, li) }
;

binding:
  id = LIDENT ; EQUAL ; e = expr { (id, e) }
;

branch:
  p = pattern ; ARROW ; e = expr { (p, e) }
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