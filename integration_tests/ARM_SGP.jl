if !("." in LOAD_PATH) # for easier local testing
    push!(LOAD_PATH, ".")
end
import TurbulenceConvection
using TurbulenceConvection
using Test

include(joinpath("utils", "main.jl"))
include(joinpath("utils", "generate_namelist.jl"))
include(joinpath("utils", "compute_mse.jl"))
using .NameList

best_mse = OrderedDict()
best_mse["qt_mean"] = 3.0998954346529128e-01
best_mse["updraft_area"] = 1.9456011695010488e+03
best_mse["updraft_w"] = 3.1996277691153108e+02
best_mse["updraft_qt"] = 1.2645380500158543e+01
best_mse["updraft_thetal"] = 2.7684653720274000e+01
best_mse["u_mean"] = 8.7998547277817863e+01
best_mse["tke_mean"] = 6.2536497518678300e+02
best_mse["temperature_mean"] = 1.3316949170699788e-04
best_mse["ql_mean"] = 2.5314704151953435e+02
best_mse["thetal_mean"] = 1.3123118572261322e-04
best_mse["Hvar_mean"] = 1.0770693519961310e+03
best_mse["QTvar_mean"] = 1.9003025309800736e+02

@testset "ARM_SGP" begin
    println("Running ARM_SGP...")
    namelist = default_namelist("ARM_SGP")
    namelist["meta"]["uuid"] = "01"
    ds_filename = @time main(namelist)

    computed_mse = Dataset(ds_filename, "r") do ds
        Dataset(joinpath(PyCLES_output_dataset_path, "ARM_SGP.nc"), "r") do ds_pycles
            Dataset(joinpath(SCAMPy_output_dataset_path, "ARM_SGP.nc"), "r") do ds_scampy
                compute_mse(
                    "ARM_SGP",
                    best_mse,
                    joinpath(dirname(ds_filename), "comparison");
                    ds_turb_conv = ds,
                    ds_scampy = ds_scampy,
                    ds_pycles = ds_pycles,
                    plot_comparison = true,
                    t_start = 8 * 3600,
                    t_stop = 11 * 3600,
                )
            end
        end
    end

    test_mse(computed_mse, best_mse, "qt_mean")
    test_mse(computed_mse, best_mse, "updraft_area")
    test_mse(computed_mse, best_mse, "updraft_w")
    test_mse(computed_mse, best_mse, "updraft_qt")
    test_mse(computed_mse, best_mse, "updraft_thetal")
    test_mse(computed_mse, best_mse, "u_mean")
    test_mse(computed_mse, best_mse, "tke_mean")
    test_mse(computed_mse, best_mse, "temperature_mean")
    test_mse(computed_mse, best_mse, "ql_mean")
    test_mse(computed_mse, best_mse, "thetal_mean")
    test_mse(computed_mse, best_mse, "Hvar_mean")
    test_mse(computed_mse, best_mse, "QTvar_mean")
    nothing
end
