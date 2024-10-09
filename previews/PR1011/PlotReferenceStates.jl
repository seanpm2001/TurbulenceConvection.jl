import TurbulenceConvection
const TC = TurbulenceConvection
import Plots
import NCDatasets
import Logging
import CLIMAParameters
import ClimaCore
const CC = ClimaCore
const tc_dir = pkgdir(TurbulenceConvection)
include(joinpath(tc_dir, "driver", "generate_namelist.jl"))
include(joinpath(tc_dir, "driver", "Cases.jl"))
include(joinpath(tc_dir, "driver", "parameter_set.jl"))
include(joinpath(tc_dir, "driver", "dycore.jl"))
import .NameList
import .Cases
function export_ref_profile(case_name::String)
    TC = TurbulenceConvection
    namelist = NameList.default_namelist(case_name)
    param_set = create_parameter_set(namelist)
    namelist["meta"]["uuid"] = "01"

    FT = Float64
    grid = TC.Grid(FT(namelist["grid"]["dz"]), namelist["grid"]["nz"])
    case = Cases.get_case(namelist)
    surf_ref_state = Cases.surface_ref_state(case, param_set, namelist)
    ts_g = surf_ref_state

    aux_vars(FT) = (; ρ0 = FT(0), α0 = FT(0), p0 = FT(0))
    cent = TC.FieldFromNamedTuple(TC.center_space(grid), aux_vars(FT))
    face = TC.FieldFromNamedTuple(TC.face_space(grid), aux_vars(FT))

    p0_c = cent.p0
    ρ0_c = cent.ρ0
    α0_c = cent.α0
    p0_f = face.p0
    ρ0_f = face.ρ0
    α0_f = face.α0
    compute_ref_state!(p0_c, ρ0_c, α0_c, p0_f, ρ0_f, α0_f, grid, param_set; ts_g)

    zc = vec(grid.zc)
    zf = vec(grid.zf)
    ρ0_c = vec(cent.ρ0)
    p0_c = vec(cent.p0)
    α0_c = vec(cent.α0)
    ρ0_f = vec(face.ρ0)
    p0_f = vec(face.p0)
    α0_f = vec(face.α0)

    p1 = Plots.plot(ρ0_c, zc ./ 1000; label = "centers")
    Plots.plot!(ρ0_f, zf ./ 1000; label = "faces")
    Plots.plot!(size = (1000, 400))
    Plots.plot!(margin = 5 * Plots.mm)
    Plots.xlabel!("ρ_0")
    Plots.ylabel!("z (km)")
    Plots.title!("ρ_0")

    p2 = Plots.plot(p0_c ./ 1000, zc ./ 1000; label = "centers")
    Plots.plot!(p0_f ./ 1000, zf ./ 1000; label = "faces")
    Plots.plot!(size = (1000, 400))
    Plots.plot!(margin = 5 * Plots.mm)
    Plots.xlabel!("p_0 (kPa)")
    Plots.ylabel!("z (km)")
    Plots.title!("p_0 (kPa)")

    p3 = Plots.plot(α0_c, zc ./ 1000; label = "centers")
    Plots.plot!(α0_f, zf ./ 1000; label = "faces")
    Plots.plot!(size = (1000, 400))
    Plots.plot!(margin = 5 * Plots.mm)
    Plots.xlabel!("α_0")
    Plots.ylabel!("z (km)")
    Plots.title!("α_0")
    Plots.plot(p1, p2, p3; layout = (1, 3))
    Plots.savefig("$case_name.svg")

end

Logging.with_logger(Logging.NullLogger()) do # silence output
    for case_name in (
        "Bomex",
        "life_cycle_Tan2018",
        "Soares",
        "Rico",
        "ARM_SGP",
        "DYCOMS_RF01",
        "GABLS",
        "SP",
        "DryBubble",
        "TRMM_LBA",
        "GATE_III",
    )
        export_ref_profile(case_name)
    end
end