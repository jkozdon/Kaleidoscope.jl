
function parse(filename)
    lex = Lexer(filename)
    while true
        t = gettok!(lex)
        if t.tok == tok_eof
            return
        elseif t.val == ";"
            continue
        elseif t.tok == tok_def
            # TODO: Handle definition
            error("def")
        elseif t.tok == tok_extern
            # TODO: Handle extern
            error("extern")
        elseif t.tok == tok_identifier
            # TODO: Top-level expression
            error("identifier")
        else
            error("input problem")
        end
    end
end
