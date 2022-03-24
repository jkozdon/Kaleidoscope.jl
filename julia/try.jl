include("lexer.jl")

let
    fid = open("fib.kl", "r")
    lex = Lexer(fid, read(fid, Char))

    tok = gettok!(lex)
    @show tok
    while tok.tok != tok_eof
        tok = gettok!(lex)
        @show tok
    end
end
