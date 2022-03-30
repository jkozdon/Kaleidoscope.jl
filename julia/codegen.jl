struct Scope
    names::Dict{String, LLVM.Value}
    parent::Scope
    Scope(parent) = new(Dict{String, LLVM.Value}(), parent)
    Scope() = new(Dict{String, LLVM.Value}())
end

mutable struct CodeGen
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
    # If the function prototype isn't in the module already, add it
    if !haskey(LLVM.functions(cg.mod), ast.callee)
        codegen(cg, PrototypeAST(ast.callee, length(ast.args)), scope)
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

function codegen(cg::CodeGen, ast::PrototypeAST, scope::Scope)
    # Array of argument types
    doubles = fill(LLVM.DoubleType(cg.ctx), length(ast.args))

    # Create the function type for the call
    func_type = LLVM.FunctionType(LLVM.DoubleType(cg.ctx), doubles)

    # Create the IR function for the call
    func = LLVM.Function(cg.mod, ast.name, func_type)

    # Link for definition or call outside the cg.mod
    LLVM.linkage!(func, LLVM.API.LLVMExternalLinkage)

    # Set the name for all the parameters
    for (param, arg) in zip(LLVM.parameters(func), ast.args)
        LLVM.name!(param, arg)
    end

    return func
end

function codegen(cg::CodeGen, ast::FunctionAST, scope::Scope)

    # Create the function prototype
    func = codegen(cg, ast.proto, scope)

    # Create new basic block
    basicblock = LLVM.BasicBlock(func, "entry"; ctx = cg.ctx)
    LLVM.position!(cg.builder, basicblock)

    # Create a new scope for the function call
    new_scope = Scope(scope)

    # push parameters for the function call
    for param in LLVM.parameters(func)
        name = LLVM.name(param)
        new_scope.names[name] = param
    end

    retval = codegen(cg, ast.body, new_scope)

    LLVM.ret!(cg.builder, retval)
    LLVM.verify(func)

    return func
end

function codegen(cg::CodeGen, ast::IfExprAST, scope::Scope)
    new_scope = Scope(scope)

    # Generate code for conditional
    cond_cg = codegen(cg, ast.cond_expr, new_scope)
    zero = LLVM.ConstantFP(LLVM.DoubleType(cg.ctx), 0.0)
    condV = LLVM.fcmp!(cg.builder, LLVM.API.LLVMRealONE, cond_cg, zero, "ifcond")

    # Generate basic blocks for then, else, and merge
    thefunction = LLVM.parent(LLVM.position(cg.builder))
    # XXX: When not create without function as in tutorial???
    thenBB = LLVM.BasicBlock(thefunction, "then"; cg.ctx)
    elseBB = LLVM.BasicBlock(thefunction, "else"; cg.ctx)
    mergeBB = LLVM.BasicBlock(thefunction, "ifcont"; cg.ctx)

    # Conditional branch using condV for then and else
    LLVM.br!(cg.builder, condV, thenBB, elseBB)

    ## then branch
    # Go to the end of the then basic block
    LLVM.position!(cg.builder, thenBB)
    # Generate code for the then
    then_cg = codegen(cg, ast.then_expr, scope)
    # branch to merge basic block
    LLVM.br!(cg.builder, mergeBB)
    # Reset the then basic block position
    thenBB = position(cg.builder)

    ## else branch
    # Go to the end of the else basic block
    LLVM.position!(cg.builder, elseBB)
    # Generate code for the else
    else_cg = codegen(cg, ast.else_expr, scope)
    # branch to merge basic block
    LLVM.br!(cg.builder, mergeBB)
    # Reset the else basic block position
    elseBB = position(cg.builder)

    ## merge command
    LLVM.position!(cg.builder, mergeBB)
    phi = LLVM.phi!(cg.builder, LLVM.DoubleType(cg.ctx), "iftmp")
    append!(LLVM.incoming(phi), [(then_cg, thenBB), (else_cg, elseBB)])
    error()
end
