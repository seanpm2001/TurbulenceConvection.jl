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
best_mse["qt_mean"] = 3.7999769022213942e-02
best_mse["ql_mean"] = 8.4794189122776036e+00
best_mse["updraft_area"] = 2.2364090186153348e+02
best_mse["updraft_w"] = 3.4475661482890558e+00
best_mse["updraft_qt"] = 1.3839010357798487e+00
best_mse["updraft_thetal"] = 1.2733570833710051e+01
best_mse["v_mean"] = 4.0030786550849442e+01
best_mse["u_mean"] = 3.5747430896153816e+01
best_mse["tke_mean"] = 1.4611287811858389e+01
best_mse["temperature_mean"] = 3.8666969165057168e-06
best_mse["thetal_mean"] = 5.7397807898569714e-06
best_mse["Hvar_mean"] = 8.4325692999540202e+04
best_mse["QTvar_mean"] = 6.3010689185932879e+03


@testset "DYCOMS_RF01" begin
    println("Running DYCOMS_RF01...")
    namelist = default_namelist("DYCOMS_RF01")
    namelist["meta"]["uuid"] = "01"
    ds_filename = @time main(namelist)

    computed_mse = Dataset(ds_filename, "r") do ds
        Dataset(joinpath(PyCLES_output_dataset_path, "DYCOMS_RF01.nc"), "r") do ds_pycles
            Dataset(joinpath(SCAMPy_output_dataset_path, "DYCOMS_RF01.nc"), "r") do ds_scampy
                compute_mse(
                    "DYCOMS_RF01",
                    best_mse,
                    joinpath(dirname(ds_filename), "comparison");
                    ds_turb_conv = ds,
                    ds_scampy = ds_scampy,
                    ds_pycles = ds_pycles,
                    plot_comparison = true,
                )
            end
        end
    end

    test_mse(computed_mse, best_mse, "qt_mean")
    test_mse(computed_mse, best_mse, "updraft_area")
    test_mse(computed_mse, best_mse, "updraft_w")
    test_mse(computed_mse, best_mse, "updraft_qt")
    test_mse(computed_mse, best_mse, "updraft_thetal")
    test_mse(computed_mse, best_mse, "v_mean")
    test_mse(computed_mse, best_mse, "u_mean")
    test_mse(computed_mse, best_mse, "tke_mean")
    test_mse(computed_mse, best_mse, "temperature_mean")
    test_mse(computed_mse, best_mse, "thetal_mean")
    test_mse(computed_mse, best_mse, "Hvar_mean")
    test_mse(computed_mse, best_mse, "QTvar_mean")
    nothing
end
