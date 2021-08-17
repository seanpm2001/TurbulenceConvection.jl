import TurbulenceConvection
import CLIMAParameters
using CLIMAParameters: AbstractEarthParameterSet
using CLIMAParameters.Planet

struct EarthParameterSet{NT} <: AbstractEarthParameterSet
    nt::NT
end

CLIMAParameters.Planet.MSLP(ps::EarthParameterSet) = ps.nt.MSLP
CLIMAParameters.Atmos.Microphysics.τ_cond_evap(ps::EarthParameterSet) = ps.nt.τ_cond_evap
CLIMAParameters.Atmos.EDMF.c_ε(ps::EarthParameterSet) = ps.nt.c_ε
CLIMAParameters.Atmos.EDMF.α_b(ps::EarthParameterSet) = ps.nt.α_b
CLIMAParameters.Atmos.EDMF.α_a(ps::EarthParameterSet) = ps.nt.α_a
CLIMAParameters.Atmos.EDMF.α_d(ps::EarthParameterSet) = ps.nt.α_d
CLIMAParameters.Atmos.EDMF.H_up_min(ps::EarthParameterSet) = ps.nt.H_up_min
CLIMAParameters.Atmos.EDMF.ω_pr(ps::EarthParameterSet) = ps.nt.ω_pr

#! format: off
function create_parameter_set(namelist)
    TC = TurbulenceConvection
    nt = (;
        MSLP = 100000.0, # or grab from, e.g., namelist[""][...]
        τ_cond_evap = TC.parse_namelist(namelist, "microphysics", "τ_cond_evap"; default = 10.0),
        c_ε = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "entrainment_factor"),
        c_div = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "entrainment_massflux_div_factor"; default = 0.0),
        α_b = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "pressure_normalmode_buoy_coeff1"),
        α_a = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "pressure_normalmode_adv_coeff"),
        α_d = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "pressure_normalmode_drag_coeff"),
        H_up_min = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "min_updraft_top"),
        ω_pr = TC.parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "Prandtl_number_scale"),
    )
    return EarthParameterSet(nt)
end
#! format: on
