
all: ppurs.exe
#	dune exec ./ppurs.exe --parse-only test.purs           ne marche pas ?
	dune exec ./ppurs.exe test.purs


#tests: ppurs.exe
#	bash run-tests "dune exec ./ppurs.exe"

ppurs.exe:
	dune build
	dune build ppurs.exe

explain:
	menhir --base /tmp/parser --dump --explain parser.mly
	cat /tmp/parser.conflicts

clean:
	dune clean

.PHONY: all clean ppurs.exe



