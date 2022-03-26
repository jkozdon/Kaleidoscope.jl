struct Scope
    names::Dict{String, LLVM.Value}
    parent::Scope
    function Scope(parent = undef)
        return new(Dict{String, LLVM.Value}(), parent)
    end
end

struct CodeGen
    ctx::LLVM.Context
    builder::LLVM.Builder
    mod::LLVM.Module
    function CodeGen(ctx = LLVM.Context())
        builder = LLVM.Builder(ctx)
        mod = LLVM.Module("KaleidoscopeModule"; ctx)
        return new(ctx, LLVM.Builder(ctx), mod)
    end
end

function codegen(cg::CodeGen, ast::NumberExprAST, scope::Scope)
    return LLVM.ConstantFP(LLVM.DoubleType(cg.ctx), ast.val)
end

function codegen(cg::CodeGen, ast::VariableExprAST, scope::Scope)
    name = ast.val
    while true
        name ∈ keys(scope.names) && return scope.names[name]
        if isdefined(scope, :parent)
            scope = scope.parent
        else
            error("codegen VariableExprAST \"$name\" not found in scope")
        end
    end
end

function codegen(cg::CodeGen, ast::BinaryExprAST, scope::Scope)
    L = codegen(cg, ast.lhs, scope)
    R = codegen(cg, ast.rhs, scope)

    op = ast.binop
    if op == '+'
        LLVM.fadd!(cg.builder, L, R, "addtmp")
    elseif op == '-'
        LLVM.fsub!(cg.builder, L, R, "subtmp")
    elseif op == '*'
        LLVM.fmul!(cg.builder, L, R, "multmp")
    elseif op == '<'
        L = LLVM.fcmp!(cg.builder, LLVM.API.LLVMRealOLT, L, R, "cmptmp")
        return LLVM.uitofp!(cg.builder, L, LLVM.DoubleType(cg.ctx), "booltmp")
    else
        error("codegen BinaryExprAST unknown op \"$op\"")
    end
end

function codegen(cg::CodeGen, ast::CallExprAST, scope::Scope)
    # Look up the function in module table
    if !haskey!(LLVM.functions(cg.mod), ast.callee)
        error("unknown function $(ast.callee)")
    end
    callf = LLVM.functions(cg.mod)[ast.callee]

    # Check the number of arguments
    if length(LLVM.parameters(callf)) != length(ast.args)
        error("incorrect numbers arguments")
    end

    # Create array for arguments
    argsv = [codegen(cg, v, scope) for v in ast.args]

    # create the actual call
    return LLVM.call!(cg.builder, callf, argsv, "calltmp")
end