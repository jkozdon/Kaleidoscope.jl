import LLVM
include("lexer.jl")
include("ast.jl")
include("codegen.jl")

let
    filename = "test.kl"
    klparse(filename)
end
