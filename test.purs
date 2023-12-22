module Main where
import Prelude
import Effect
import Effect.Console

class C a where
  foo:: a -> String
  
main :: Effect Unit
main = log (foo 1)

main2 :: Effect Unit
main2 = log (foo "aa")

g:: Int
g = foo
