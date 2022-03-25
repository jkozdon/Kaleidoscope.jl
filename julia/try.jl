include("lexer.jl")
include("ast.jl")

let
    filename = "test.kl"
    klparse(filename)
end
