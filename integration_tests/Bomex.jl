if !("." in LOAD_PATH) # for easier local testing
    push!(LOAD_PATH, ".")
end
import TurbulenceConvection
using Test

const tc_dir = dirname(dirname(pathof(TurbulenceConvection)))
include(joinpath(tc_dir, "driver", "main.jl"))
include(joinpath(tc_dir, "driver", "generate_namelist.jl"))
import .NameList


case_name = "Bomex"
println("Running $case_name...")
namelist = NameList.default_namelist(case_name)
namelist["meta"]["uuid"] = "01"
ds_tc_filename, return_code = main(namelist)

# include(joinpath(tc_dir, "post_processing", "compute_mse.jl"))
# include(joinpath(tc_dir, "post_processing", "mse_tables.jl"))
# best_mse = all_best_mse["Bomex"]
# computed_mse = compute_mse_wrapper(
#     case_name,
#     best_mse,
#     ds_tc_filename;
#     plot_comparison = true,
#     t_start = 4 * 3600,
#     t_stop = 6 * 3600,
# )

# open("computed_mse_$case_name.json", "w") do io
#     JSON.print(io, computed_mse)
# end

# @testset "Bomex" begin
#     for k in keys(best_mse)
#         test_mse(computed_mse, best_mse, k)
#     end
#     include(joinpath(tc_dir, "post_processing", "post_run_tests.jl"))
#     nothing
# end
