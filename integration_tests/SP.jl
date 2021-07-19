if !("." in LOAD_PATH) # for easier local testing
    push!(LOAD_PATH, ".")
end
import TurbulenceConvection
using TurbulenceConvection
using Test

include(joinpath("utils", "main.jl"))
include(joinpath("utils", "generate_paramlist.jl"))
include(joinpath("utils", "generate_namelist.jl"))
include(joinpath("utils", "compute_mse.jl"))
using .NameList
using .ParamList

@testset "SP" begin
    println("Running SP...")
    namelist = NameList.SP(default_namelist("SP"))
    paramlist = ParamList.SP(default_paramlist("SP"))
    namelist["meta"]["uuid"] = "01"
    @time main(namelist, paramlist)
end
