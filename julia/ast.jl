struct EmptyAST <: AbstractExprAST end

struct PrototypeAST <: AbstractExprAST
    name::String
    args::Vector
    function PrototypeAST(lex::Lexer)
        # Get the function name
        t = gettok!(lex)
        name = t.val
        @assert t.tok == tok_identifier

        # Eat the '('
        t = gettok!(lex)
        @assert t.tok == tok_misc && t.val == "("

        # get the args (white space separated identifier)
        args = Vector{String}()
        while true
            t = gettok!(lex)

            # If closing ')' break
            t.tok == tok_misc && t.val == ")" && break

            # save the args
            @assert t.tok == tok_identifier
            push!(args, t.val)
        end

        return new(name, args)
    end
end

struct FunctionAST
    proto::PrototypeAST
    body::AbstractExprAST
    function FunctionAST(lex::Lexer)
        proto = PrototypeAST(lex)
        body = ParseExpression(lex)
        new(proto, body)
    end
end

function ParseExpression(lex::Lexer)
    return EmptyAST()
    # LHS = ParsePrimary(lex, t)
    # return ParseBinOpRHS(0, LHS, lex)
end

function parse(filename)
    lex = Lexer(filename)
    while true
        t = gettok!(lex)
        if t.tok == tok_eof
            return
        elseif t.val == ";"
            continue
        elseif t.tok == tok_def
            # Handle definition
            ast = FunctionAST(lex)
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
