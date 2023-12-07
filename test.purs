module Main where
import Prelude
import Effect
import Effect.Console

main::Unit->Unit
main = if 5 then mod 5 4 else 2 
