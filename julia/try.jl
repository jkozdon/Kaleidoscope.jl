import LLVM
include("lexer.jl")
include("ast.jl")
include("codegen.jl")

filename = "test2.kl"
(cg, scope) = klparse(filename)
# fpm = LLVM.FunctionPassManager(cg.mod)
# LLVM.instruction_combining!(fpm)
# fn = LLVM.functions(cg.mod)["foo"]
# @show fn
# LLVM.run!(fpm, fn)
# @show fn

#=
mpm = LLVM.ModulePassManager()

fn = LLVM.functions(cg.mod)["foo"]
@show fn

for pass in (
             LLVM.instruction_combining!,
             LLVM.reassociate!,
             LLVM.gvn!,
            )

    pass(mpm)
    LLVM.run!(mpm, cg.mod)
    local fn = LLVM.functions(cg.mod)["foo"]
    @show fn
end


function run(mod::LLVM.Module, entry::String)
    res_jl = 0.0
    # LLVM.JIT(mod) do engine
        if !haskey(LLVM.functions(engine), entry)
            error("did not find entry function '$entry' in module")
        end
        f = LLVM.functions(engine)[entry]
        res = LLVM.run(engine, f)
        res_jl = convert(Float64, res, LLVM.DoubleType(LLVM.context(mod)))
        LLVM.dispose(res)
    # end
    return res_jl
end
=#
