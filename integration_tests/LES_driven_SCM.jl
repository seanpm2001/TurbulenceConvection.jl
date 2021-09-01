if !("." in LOAD_PATH) # for easier local testing
    push!(LOAD_PATH, ".")
end
import TurbulenceConvection
using TurbulenceConvection
using Test

include(joinpath("utils", "main.jl"))
include(joinpath("utils", "generate_namelist.jl"))
include(joinpath("utils", "compute_mse.jl"))
include(joinpath("utils", "mse_tables.jl"))
using .NameList

best_mse = all_best_mse["LES_driven_SCM"]

@testset "LES_driven_SCM" begin
    case_name = "LES_driven_SCM"
    println("Running $case_name...")
    namelist = NameList.default_namelist(case_name)
    namelist["meta"]["uuid"] = "01"
    ds_tc_filename = @time main(namelist)

    computed_mse = compute_mse_wrapper(
        case_name,
        best_mse,
        ds_tc_filename;
        ds_les_filename = joinpath(
            NameList.LESDrivenSCM_output_dataset_path,
            "Stats.cfsite23_HadGEM2-A_amip_2004-2008.07.nc",
        ),
        plot_comparison = true,
        t_start = 6 * 3600,
        t_stop = 12 * 3600,
    )

    open("computed_mse_$case_name.json", "w") do io
        JSON.print(io, computed_mse)
    end

    for k in keys(best_mse)
        test_mse(computed_mse, best_mse, k)
    end
    nothing

end