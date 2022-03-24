include("lexer.jl")
include("ast.jl")

let
    filename = "fib.kl"
    parse(filename)
end
