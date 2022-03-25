abstract type AbstractExprAST end

struct EmptyAST <: AbstractExprAST end

struct NumberExprAST <: AbstractExprAST
    val::Float64
    NumberExprAST(str::String) = new(parse(Float64, str))
end

struct VariableExprAST <: AbstractExprAST
    val::String
    VariableExprAST(str::String) = new(str)
end

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

function ParseExpression(lex::Lexer, t = gettok!(lex))
    LHS = ParsePrimary(lex, t)
    return EmptyAST()
    # return ParseBinOpRHS(0, LHS, lex)
end

function ParsePrimary(lex, t)
    if t.tok == tok_identifier
        return ParseIdentifierExpr(lex, t)
    elseif t.tok == tok_number
        return NumberExprAST(t.val)
    elseif t.val =="("
        error("ParsePrimary: paren")
    else
        error("ParsePrimary: unkown token")
    end
end

function ParseIdentifierExpr(lex::Lexer, t::Token)
    lex.next.val != "(" && return VariableExprAST(t.val)

    t = gettok!(lex)
    @assert t.tok == tok_misc && t.val == "("
    args = Vector{AbstractExprAST}()
    while true
        t = gettok!(lex)
        if t.tok == tok_misc
            if t.val == ")"
                break
            elseif t.val == ","
                continue
            else
                error("unknown tok_misc")
            end
        elseif t.tok == tok_identifier
            push!(args, ParseExpression(lex, t))
        else
            error("unknown expression")
        end
    end
end


function klparse(filename)
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
            error("klparse: extern")
        elseif t.tok == tok_identifier
            # TODO: Top-level expression
            error("klparse: identifier")
        else
            error("klparse: input problem")
        end
    end
end
