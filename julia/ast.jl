using Logging
BinopPrecedence = Dict{Char, Int}()
BinopPrecedence['<'] = 10
BinopPrecedence['>'] = 10
BinopPrecedence['+'] = 20
BinopPrecedence['-'] = 20
BinopPrecedence['*'] = 40
BinopPrecedence['/'] = 40
BinopPrecedence['\\'] = 40

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

struct BinaryExprAST{LHS <: AbstractExprAST, RHS <: AbstractExprAST} <: AbstractExprAST
    binop::Char
    lhs::LHS
    rhs::RHS
    function BinaryExprAST(btok::Token, lhs::LHS, rhs::RHS) where {LHS, RHS}
        @assert btok.tok == tok_misc
        binop = only(btok.val)
        @assert binop ∈ keys(BinopPrecedence)
        return new{LHS, RHS}(binop, lhs, rhs)
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

struct CallExprAST <: AbstractExprAST
    callee::String
    args::Vector{AbstractExprAST}
end

function ParseExpression(lex::Lexer, t = gettok!(lex))
    lhs = ParsePrimary(lex, t)
    return ParseBinOpRHS(0, lhs, lex)
end

function GetNextTokPrec(lex::Lexer)
    if lex.next.tok == tok_eof
        return -1
    else
        l = first(lex.next.val)
        if isletter(l)
            return -1
        elseif l ∈ keys(BinopPrecedence)
            return BinopPrecedence[l]
        else
            return -1
        end
    end
end

function ParseBinOpRHS(ExprPrec, lhs::AbstractExprAST, lex::Lexer)
    while true
        TokPrec = GetNextTokPrec(lex)

        # Not a binary operator
        TokPrec < ExprPrec && (return lhs)

        # Get the binary operator
        BinOp = gettok!(lex)

        # get the RHS expression
        rhs = ParsePrimary(lex)

        # If next token has higher precedence than current token then RHS should
        # bind with the next token
        if TokPrec < GetNextTokPrec(lex)
            rhs = ParseBinOpRHS(TokPrec + 1, rhs, lex)
        end

        # Create a binary operator with the lhs and rhs
        lhs = BinaryExprAST(BinOp, lhs, rhs)
    end
end

function ParsePrimary(lex, t = gettok!(lex))
    if t.tok == tok_identifier
        return ParseIdentifierExpr(lex, t)
    elseif t.tok == tok_number
        return NumberExprAST(t.val)
    elseif t.val =="("
        ast = ParseExpression(lex)
        t = gettok!(lex)
        @assert t.val == ")"
        return ast
    else
        error("ParsePrimary: unkown token: $t")
    end
end

function ParseIdentifierExpr(lex::Lexer, t::Token)
    # Not a variable, just an expression
    lex.next.val != "(" && return VariableExprAST(t.val)

    callee = t.val

    # Eat the function arguments
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
    return CallExprAST(callee, args)
end


function klparse(input)
    lex = Lexer(input)
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
            ast = PrototypeAST(lex)
        elseif t.tok == tok_identifier
            # TODO: Top-level expression
            error("klparse: identifier")
        else
            error("klparse: input problem")
        end
        @info """Parsed:
        $ast"""
    end
end
