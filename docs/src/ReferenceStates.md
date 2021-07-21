# Reference States

```@example
import TurbulenceConvection
import Plots
using NCDatasets
tc_dir = dirname(dirname(pathof(TurbulenceConvection)))
include(joinpath(tc_dir, "integration_tests", "utils", "generate_namelist.jl"))
include(joinpath(tc_dir, "integration_tests", "utils", "generate_paramlist.jl"))
include(joinpath(tc_dir, "integration_tests", "utils", "Cases.jl"))
using .NameList
using .ParamList
import .Cases
function export_ref_profile(case_name::String)
    namelist = default_namelist(case_name)
    paramlist = default_paramlist(case_name)
    grid = TurbulenceConvection.Grid(namelist)
    ref_state = TurbulenceConvection.ReferenceState(grid)
    Stats = TurbulenceConvection.NetCDFIO_Stats(namelist, paramlist, grid)
    case = Cases.CasesFactory(namelist, paramlist, grid, ref_state)
    Cases.initialize_reference(case, grid, ref_state, Stats)
    Dataset(joinpath(Stats.path_plus_file), "r") do ds
        zc = ds.group["profiles"]["z_half"][:]
        zf = ds.group["profiles"]["z"][:]
        ρc_0 = ds.group["reference"]["rho0_half"][:]
        pc_0 = ds.group["reference"]["p0_half"][:]
        αc_0 = ds.group["reference"]["alpha0_half"][:]
        ρf_0 = ds.group["reference"]["rho0"][:]
        pf_0 = ds.group["reference"]["p0"][:]
        αf_0 = ds.group["reference"]["alpha0"][:]

        p1 = Plots.plot(ρc_0, zc ./ 1000;label="centers")
        Plots.plot!(ρf_0, zf ./ 1000;label="faces")
        Plots.plot!(size=(1000,400))
        Plots.plot!(margin=5Plots.mm)
        Plots.xlabel!("ρ_0")
        Plots.ylabel!("z (km)")
        Plots.title!("ρ_0")

        p2 = Plots.plot(pc_0 ./ 1000, zc ./ 1000;label="centers")
        Plots.plot!(pf_0 ./ 1000, zf ./ 1000;label="faces")
        Plots.plot!(size=(1000,400))
        Plots.plot!(margin=5Plots.mm)
        Plots.xlabel!("p_0 (kPa)")
        Plots.ylabel!("z (km)")
        Plots.title!("p_0 (kPa)")

        p3 = Plots.plot(αc_0, zc ./ 1000;label="centers")
        Plots.plot!(αf_0, zf ./ 1000;label="faces")
        Plots.plot!(size=(1000,400))
        Plots.plot!(margin=5Plots.mm)
        Plots.xlabel!("α_0")
        Plots.ylabel!("z (km)")
        Plots.title!("α_0")
        Plots.plot(p1,p2,p3; layout=(1,3))
        Plots.savefig("$case_name.svg")
    end
end
for case_name in (
    "Bomex",
    "life_cycle_Tan2018",
    "Soares",
    "Rico",
    "TRMM_LBA",
    "ARM_SGP",
    "GATE_III",
    "DYCOMS_RF01",
    "GABLS",
    "SP",
    "DryBubble",
)
    export_ref_profile(case_name)
end;
```

## Bomex
![](Bomex.svg)

## life\_cycle\_Tan2018
![](life_cycle_Tan2018.svg)

## Soares
![](Soares.svg)

## Rico
![](Rico.svg)

## TRMM\_LBA
![](TRMM_LBA.svg)

## ARM\_SGP
![](ARM_SGP.svg)

## GATE\_III
![](GATE_III.svg)

## DYCOMS\_RF01
![](DYCOMS_RF01.svg)

## GABLS
![](GABLS.svg)

## SP
![](SP.svg)

## DryBubble
![](DryBubble.svg)

