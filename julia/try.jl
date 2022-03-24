include("lexer.jl")
include("ast.jl")

let
    filename = "fib.kl"
    lex = Lexer(filename)

    while true
        tok = gettok!(lex)
        tok.tok == tok_eof && break
        if tok.tok == tok_number
        elseif tok.tok == tok_identifier
        end
    end
end
