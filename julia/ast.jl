using Logging
BinopPrecedence = Dict{Char, Int}()
BinopPrecedence['<'] = 10
# BinopPrecedence['>'] = 10
BinopPrecedence['+'] = 20
BinopPrecedence['-'] = 20
BinopPrecedence['*'] = 40
# BinopPrecedence['/'] = 40
# BinopPrecedence['\\'] = 40

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

struct IfExprAST <: AbstractExprAST
    cond_expr::AbstractExprAST
    then_expr::AbstractExprAST
    else_expr::AbstractExprAST
    function IfExprAST(lex::Lexer)
        cond_expr = ParseExpression(lex)
        t = gettok!(lex)
        @assert t.tok == tok_then
        then_expr = ParseExpression(lex)
        t = gettok!(lex)
        @assert t.tok == tok_else
        else_expr = ParseExpression(lex)
        new(cond_expr, then_expr, else_expr)
    end
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
    function PrototypeAST(name::String, numargs::Int)
        args = fill("tmp", numargs)
        return new(name, args)
    end
    PrototypeAST(name::String, args = Vector{String}()) = new(name, args)
end

struct BinaryExprAST{LHS <: AbstractExprAST, RHS <: AbstractExprAST} <: AbstractExprAST
    binop::Char
    lhs::LHS
    rhs::RHS
    function BinaryExprAST(btok::Token, lhs::LHS, rhs::RHS) where {LHS, RHS}
        @assert btok.tok == tok_misc
        binop = only(btok.val)
        @assert binop ??? keys(BinopPrecedence)
        return new{LHS, RHS}(binop, lhs, rhs)
    end
end

struct FunctionAST
    proto::PrototypeAST
    body::AbstractExprAST
end
function FunctionAST(lex::Lexer)
    proto = PrototypeAST(lex)
    body = ParseExpression(lex)
    return FunctionAST(proto, body)
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
        elseif l ??? keys(BinopPrecedence)
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
    elseif t.tok == tok_if
        ast = IfExprAST(lex)
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
        else
            push!(args, ParseExpression(lex, t))
        end
    end
    return CallExprAST(callee, args)
end

function ParseTopLevelExpr(lex::Lexer, t::Token)
    proto = PrototypeAST("__anon_expr")
    body = ParseExpression(lex, t)
    return FunctionAST(proto, body)
end

function listfunctions(mod)
    println("Functions:")
    println.("    ", LLVM.name.(LLVM.functions(mod)))
    nothing
end

function klparse(inputs = nothing; cg = CodeGen(), scope = Scope())
    if isnothing(inputs)
        inputs = (stdin, )
    elseif !(inputs isa Tuple)
        inputs = (inputs,)
    end
    jit = LLVM.JIT(cg.mod)
    for input in inputs
        if input isa Base.TTY
            print("kaleidoscope> ")
        end
        lex = Lexer(input)
        while true
            t = gettok!(lex)
            if t.tok == tok_eof
                break
            elseif t.val == ";"
                continue
            elseif t.tok == tok_def
                # Handle definition
                ast = FunctionAST(lex)
                parse_type = "function definition:"
            elseif t.tok == tok_extern
                # Handle extern
                ast = PrototypeAST(lex)
                parse_type = "extern"
            else
                # Top-level expression
                ast = ParseTopLevelExpr(lex, t)
                parse_type = "top-level expression"
            end
            #=
            @info """Parsed $(parse_type):
            $(codegen(cg, ast, scope))
            """
            =#
            codegen(cg, ast, scope)
            push!(jit, cg.mod)

            # If this is a top-level expression, execute it
            entry = "__anon_expr"
            if haskey(LLVM.functions(cg.mod), entry)
                f = LLVM.functions(jit)[entry]
                res_jl = 0.0
                res = LLVM.run(jit, f)
                res_jl = convert(Float64, res, LLVM.DoubleType(cg.ctx))
                LLVM.dispose(res)
                LLVM.dispose(cg.mod)
                println(res_jl)
            end
            if input isa Base.TTY
                print("kaleidoscope> ")
            end

            # Create a new module for next function
            # FIXME: Do we need a new Context too?
            cg.mod = LLVM.Module("KaleidoscopeModule"; cg.ctx)
        end
    end
    return (cg = cg, scope = scope)
end
