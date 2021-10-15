"""
    PrecipFormation

Storage for tendencies due to precipitation formation

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct PrecipFormation{FT}
    θ_liq_ice_tendency::FT
    qt_tendency::FT
    qr_tendency::FT
end

"""
    EntrDetr

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct EntrDetr{FT}
    "Dynamical entrainment"
    ε_dyn::FT
    "Dynamical detrainment"
    δ_dyn::FT
    "Turbulent entrainment"
    ε_turb::FT
    "Horizontal eddy-diffusivity"
    K_ε::FT
end

"""
    MoistureDeficitEntr

My entrainment detrainment model

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct MoistureDeficitEntr{FT}
    "updraft liquid water"
    q_liq_up::FT
    "environment liquid water"
    q_liq_en::FT
    "updraft vertical velocity"
    w_up::FT
    "environment vertical velocity"
    w_en::FT
    "updraft buoyancy"
    b_up::FT
    "environment buoyancy"
    b_en::FT
    "environment tke"
    tke::FT
    "updraft momentum divergence"
    dMdz::FT
    "updraft momentum"
    M::FT
    "updraft area fraction"
    a_up::FT
    "environment area fraction"
    a_en::FT
    "pressure plume spacing"
    R_up::FT
    "updraft relative humidity"
    RH_up::FT
    "environment relative humidity"
    RH_en::FT
end

"""
    MixLen

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct MixLen{FT}
    "minimum length number"
    min_len_ind::Int
    "mixing length"
    mixing_length::FT
    "length ratio"
    ml_ratio::FT
end

"""
    MinDisspLen

Minimum dissipation model

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct MinDisspLen{FT, T}
    "height"
    z::FT
    "obukhov length"
    obukhov_length::FT
    "surface TKE values"
    tke_surf::FT
    "u star - surface velocity scale"
    ustar::FT
    "turbulent Prandtl number"
    Pr::FT
    "reference pressure"
    p0::FT
    "environmental vertical buoyancy gradient"
    ∂b∂z::FT
    "env shear"
    Shear²::FT
    "virtual potential temperature gradient"
    ∂θv∂z::FT
    "total specific humidity gradient"
    ∂qt∂z::FT
    "liquid ice potential temperature gradient"
    ∂θl∂z::FT
    "virtual potential temperature"
    θv::FT
    "environment turbulent kinetic energy"
    tke::FT
    "environment area"
    a_en::FT
    "environment velocity at cell center"
    wc_en::FT
    "updraft velocity at cell center"
    wc_up::T
    "updraft area"
    a_up::T
    "up draft turbulent entrainment"
    ε_turb::T
    "updraft dynamic detrainment"
    δ_dyn::T
    "environment cloud fraction"
    en_cld_frac::FT
    "environment liquid-ice potential temperature"
    θ_li_en::FT
    "environment liquid water specific humidity"
    ql_en::FT
    "environment total specific humidity"
    qt_en::FT
    "environment temperature"
    T_en::FT
    "number of updraft"
    N_up::Int
end


"""
    GradBuoy

Environmental buoyancy gradients.

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct GradBuoy{FT}
    "environmental vertical buoyancy gradient"
    ∂b∂z::FT
    "vertical buoyancy gradient in the dry part of the environment"
    ∂b∂z_dry::FT
    "vertical buoyancy gradient in the cloudy part of the environment"
    ∂b∂z_cloudy::FT
end

abstract type EnvBuoyGradClosure end
struct BuoyGradTan2018 <: EnvBuoyGradClosure end
struct BuoyGradQuadratures <: EnvBuoyGradClosure end

"""
    EnvBuoyGrad

Variables used in the environmental buoyancy gradient computation.

$(DocStringExtensions.FIELDS)
"""
Base.@kwdef struct EnvBuoyGrad{FT, EBC <: EnvBuoyGradClosure}
    "virtual potential temperature in the non cloudy part"
    thv_dry::FT
    "temperature in the cloudy part"
    t_cloudy::FT
    "vapor specific humidity  in the cloudy part"
    qv_cloudy::FT
    "total specific humidity in the cloudy part"
    qt_cloudy::FT
    "potential temperature in the cloudy part"
    th_cloudy::FT
    "liquid ice potential temperature in the cloudy part"
    thl_cloudy::FT
    "virtual potential temperature gradient in the non cloudy part"
    ∂θv∂z_dry::FT
    "total specific humidity gradient in the cloudy part"
    ∂qt∂z_cloudy::FT
    "liquid ice potential temperature gradient in the cloudy part"
    ∂θl∂z_cloudy::FT
    "reference pressure"
    p0::FT
    "cloud fraction"
    en_cld_frac::FT
    "specific volume"
    alpha0::FT
end
function EnvBuoyGrad(::EBG; thv_dry::FT, bg_kwargs...) where {FT <: Real, EBG <: EnvBuoyGradClosure}
    return EnvBuoyGrad{FT, EBG}(; thv_dry, bg_kwargs...)
end

# function EnvBuoyGrad(::BuoyGradQuadratures; thv_dry::FT, bg_kwargs...) where {FT <: Real}
#     return EnvBuoyGrad{FT, BuoyGradQuadratures}(; thv_dry, bg_kwargs...)
# end

struct RainVariable{T}
    name::String
    units::String
    values::T
    function RainVariable(grid, name, units)
        values = center_field(grid)
        return new{typeof(values)}(name, units, values)
    end
end

Base.@kwdef mutable struct RainVariables
    rain_model::String = "default_rain_model"
    mean_rwp::Float64 = 0
    cutoff_rain_rate::Float64 = 0
    QR::RainVariable
end
function RainVariables(namelist, grid::Grid)

    QR = RainVariable(grid, "qr_mean", "kg/kg")

    rain_model = parse_namelist(
        namelist,
        "microphysics",
        "rain_model";
        default = "None",
        valid_options = ["None", "cutoff", "clima_1m"],
    )

    if !(rain_model in ["None", "cutoff", "clima_1m"])
        error("rain model not recognized")
    end

    return RainVariables(; rain_model, QR)
end

struct RainPhysics{T}
    θ_liq_ice_tendency_rain_evap::T
    qt_tendency_rain_evap::T
    qr_tendency_rain_evap::T
    qr_tendency_advection::T
    function RainPhysics(grid::Grid)
        θ_liq_ice_tendency_rain_evap = center_field(grid)
        qt_tendency_rain_evap = center_field(grid)
        qr_tendency_rain_evap = center_field(grid)
        qr_tendency_advection = center_field(grid)
        return new{typeof(θ_liq_ice_tendency_rain_evap)}(
            θ_liq_ice_tendency_rain_evap,
            qt_tendency_rain_evap,
            qr_tendency_rain_evap,
            qr_tendency_advection,
        )
    end
end

struct VariablePrognostic{T}
    values::T
    tendencies::T
    name::String
    units::String
    function VariablePrognostic(grid, loc, name, units)
        # Value at the current timestep
        values = field(grid, loc)
        # Value at the next timestep, used for calculating turbulence tendencies
        tendencies = field(grid, loc)
        return new{typeof(values)}(values, tendencies, name, units)
    end
end

struct VariableDiagnostic{T}
    values::T
    name::String
    units::String
    function VariableDiagnostic(grid, loc, name, units)
        # Value at the current timestep
        values = field(grid, loc)
        # Placement on staggered grid
        return new{typeof(values)}(values, name, units)
    end
end

struct UpdraftVariable{A1, A2}
    values::A2
    new::A2
    tendencies::A2
    bulkvalues::A1
    name::String
    units::String
    function UpdraftVariable(grid, nu, loc, name, units)
        values = field(grid, loc, nu)
        new = field(grid, loc, nu) # needed for prognostic updrafts
        tendencies = field(grid, loc, nu)
        bulkvalues = field(grid, loc)
        A1 = typeof(bulkvalues)
        A2 = typeof(values)
        return new{A1, A2}(values, new, tendencies, bulkvalues, name, units)
    end
end

mutable struct UpdraftVariables{A1}
    n_updrafts::Int
    W::UpdraftVariable
    Area::UpdraftVariable
    QT::UpdraftVariable
    QL::UpdraftVariable
    RH::UpdraftVariable
    H::UpdraftVariable
    T::UpdraftVariable
    B::UpdraftVariable
    prognostic::Bool
    updraft_fraction::Float64
    cloud_fraction::A1
    cloud_base::A1
    cloud_top::A1
    cloud_cover::A1
    updraft_top::A1
    lwp::Float64
    function UpdraftVariables(nu, namelist, grid::Grid)
        n_updrafts = nu

        W = UpdraftVariable(grid, nu, "full", "w", "m/s")

        Area = UpdraftVariable(grid, nu, "half", "area_fraction", "[-]")
        QT = UpdraftVariable(grid, nu, "half", "qt", "kg/kg")
        QL = UpdraftVariable(grid, nu, "half", "ql", "kg/kg")
        RH = UpdraftVariable(grid, nu, "half", "RH", "%")
        H = UpdraftVariable(grid, nu, "half", "thetal", "K")
        T = UpdraftVariable(grid, nu, "half", "temperature", "K")
        B = UpdraftVariable(grid, nu, "half", "buoyancy", "m^2/s^3")

        prognostic = true
        updraft_fraction = namelist["turbulence"]["EDMF_PrognosticTKE"]["surface_area"]

        # cloud and rain diagnostics for output
        cloud_fraction = center_field(grid)

        cloud_base = zeros(nu)
        cloud_top = zeros(nu)
        cloud_cover = zeros(nu)
        updraft_top = zeros(nu)

        lwp = 0.0
        A1 = typeof(cloud_fraction)
        return new{A1}(
            n_updrafts,
            W,
            Area,
            QT,
            QL,
            RH,
            H,
            T,
            B,
            prognostic,
            updraft_fraction,
            cloud_fraction,
            cloud_base,
            cloud_top,
            cloud_cover,
            updraft_top,
            lwp,
        )
    end
end

Base.@kwdef mutable struct GridMeanVariables{PS}
    param_set::PS
    lwp::Float64
    cloud_base::Float64
    cloud_top::Float64
    cloud_cover::Float64
    U::VariablePrognostic
    V::VariablePrognostic
    W::VariablePrognostic
    QT::VariablePrognostic
    RH::VariablePrognostic
    H::VariablePrognostic
    QL::VariableDiagnostic
    T::VariableDiagnostic
    B::VariableDiagnostic
    cloud_fraction::VariableDiagnostic
    EnvThermo_scheme::String
    TKE::VariableDiagnostic
    W_third_m::VariableDiagnostic
    QTvar::VariableDiagnostic
    QT_third_m::VariableDiagnostic
    Hvar::VariableDiagnostic
    H_third_m::VariableDiagnostic
    HQTcov::VariableDiagnostic
end
function GridMeanVariables(namelist, grid::Grid, param_set::PS) where {PS}
    lwp = 0.0
    cloud_base = 0.0
    cloud_top = 0.0
    cloud_cover = 0.0

    U = VariablePrognostic(grid, "half", "u", "m/s")
    V = VariablePrognostic(grid, "half", "v", "m/s")
    # Just leave this zero for now!
    W = VariablePrognostic(grid, "full", "v", "m/s")

    # Create thermodynamic variables
    QT = VariablePrognostic(grid, "half", "qt", "kg/kg")
    RH = VariablePrognostic(grid, "half", "RH", "%")

    H = VariablePrognostic(grid, "half", "thetal", "K")

    # Diagnostic Variables--same class as the prognostic variables, but we append to diagnostics list
    QL = VariableDiagnostic(grid, "half", "ql", "kg/kg")
    T = VariableDiagnostic(grid, "half", "temperature", "K")
    B = VariableDiagnostic(grid, "half", "buoyancy", "m^2/s^3")

    cloud_fraction = VariableDiagnostic(grid, "half", "cloud fraction", "-")

    EnvThermo_scheme = parse_namelist(namelist, "thermodynamics", "sgs"; default = "mean")

    #Now add the 2nd moment variables

    TKE = VariableDiagnostic(grid, "half", "tke", "m^2/s^2")
    W_third_m = VariableDiagnostic(grid, "half", "W_third_m", "m^3/s^3")

    QTvar = VariableDiagnostic(grid, "half", "qt_var", "kg^2/kg^2")
    QT_third_m = VariableDiagnostic(grid, "half", "qt_third_m", "kg^3/kg^3")
    Hvar = VariableDiagnostic(grid, "half", "thetal_var", "K^2")
    H_third_m = VariableDiagnostic(grid, "half", "thetal_third_m", "-")
    HQTcov = VariableDiagnostic(grid, "half", "thetal_qt_covar", "K(kg/kg)")

    return GridMeanVariables(;
        param_set,
        lwp,
        cloud_base,
        cloud_top,
        cloud_cover,
        U,
        V,
        W,
        QT,
        RH,
        H,
        QL,
        T,
        B,
        cloud_fraction,
        EnvThermo_scheme,
        TKE,
        W_third_m,
        QTvar,
        QT_third_m,
        Hvar,
        H_third_m,
        HQTcov,
    )
end


struct UpdraftThermodynamics{A1, A2}
    n_updraft::Int
    θ_liq_ice_tendency_rain_formation::A2
    qt_tendency_rain_formation::A2
    θ_liq_ice_tendency_rain_formation_tot::A1
    qt_tendency_rain_formation_tot::A1
    function UpdraftThermodynamics(n_updraft::Int, grid::Grid)
        # tendencies from each updraft
        θ_liq_ice_tendency_rain_formation = center_field(grid, n_updraft)
        qt_tendency_rain_formation = center_field(grid, n_updraft)
        # tendencies from all updrafts
        θ_liq_ice_tendency_rain_formation_tot = center_field(grid)
        qt_tendency_rain_formation_tot = center_field(grid)

        A1 = typeof(θ_liq_ice_tendency_rain_formation_tot)
        A2 = typeof(θ_liq_ice_tendency_rain_formation)
        return new{A1, A2}(
            n_updraft,
            θ_liq_ice_tendency_rain_formation,
            qt_tendency_rain_formation,
            θ_liq_ice_tendency_rain_formation_tot,
            qt_tendency_rain_formation_tot,
        )
    end
end

struct EnvironmentVariable{T}
    values::T
    name::String
    units::String
    function EnvironmentVariable(grid, loc, name, units)
        values = field(grid, loc)
        return new{typeof(values)}(values, name, units)
    end
end

struct EnvironmentVariable_2m{A1}
    values::A1
    dissipation::A1
    shear::A1
    entr_gain::A1
    detr_loss::A1
    press::A1
    buoy::A1
    interdomain::A1
    rain_src::A1
    name::String
    units::String
    function EnvironmentVariable_2m(grid, name, units)
        values = center_field(grid)
        dissipation = center_field(grid)
        entr_gain = center_field(grid)
        detr_loss = center_field(grid)
        buoy = center_field(grid)
        press = center_field(grid)
        shear = center_field(grid)
        interdomain = center_field(grid)
        rain_src = center_field(grid)
        return new{typeof(values)}(
            values,
            dissipation,
            shear,
            entr_gain,
            detr_loss,
            press,
            buoy,
            interdomain,
            rain_src,
            name,
            units,
        )
    end
end

Base.@kwdef mutable struct EnvironmentVariables
    W::EnvironmentVariable
    Area::EnvironmentVariable
    QT::EnvironmentVariable
    QL::EnvironmentVariable
    H::EnvironmentVariable
    RH::EnvironmentVariable
    T::EnvironmentVariable
    B::EnvironmentVariable
    cloud_fraction::EnvironmentVariable
    TKE::EnvironmentVariable_2m
    Hvar::EnvironmentVariable_2m
    QTvar::EnvironmentVariable_2m
    HQTcov::EnvironmentVariable_2m
    cloud_base::Float64 = 0
    cloud_top::Float64 = 0
    cloud_cover::Float64 = 0
    lwp::Float64 = 0
    EnvThermo_scheme::String = "default_EnvThermo_scheme"
end
function EnvironmentVariables(namelist, grid::Grid)
    W = EnvironmentVariable(grid, "full", "w", "m/s")
    QT = EnvironmentVariable(grid, "half", "qt", "kg/kg")
    QL = EnvironmentVariable(grid, "half", "ql", "kg/kg")
    RH = EnvironmentVariable(grid, "half", "RH", "%")
    H = EnvironmentVariable(grid, "half", "thetal", "K")
    T = EnvironmentVariable(grid, "half", "temperature", "K")
    B = EnvironmentVariable(grid, "half", "buoyancy", "m^2/s^3")
    Area = EnvironmentVariable(grid, "half", "env_area", "-")
    cloud_fraction = EnvironmentVariable(grid, "half", "env_cloud_fraction", "-")

    # TODO - the flag setting is repeated from Variables.pyx logic
    EnvThermo_scheme = parse_namelist(namelist, "thermodynamics", "sgs"; default = "mean")
    TKE = EnvironmentVariable_2m(grid, "tke", "m^2/s^2")
    QTvar = EnvironmentVariable_2m(grid, "qt_var", "kg^2/kg^2")
    Hvar = EnvironmentVariable_2m(grid, "thetal_var", "K^2")
    HQTcov = EnvironmentVariable_2m(grid, "thetal_qt_covar", "K(kg/kg)")

    return EnvironmentVariables(;
        W,
        Area,
        QT,
        QL,
        H,
        RH,
        T,
        B,
        cloud_fraction,
        TKE,
        Hvar,
        QTvar,
        HQTcov,
        EnvThermo_scheme,
    )
end

struct EnvironmentThermodynamics{A1}
    quadrature_order::Int
    quadrature_type::String
    qt_dry::A1
    th_dry::A1
    thv_dry::A1
    t_cloudy::A1
    qv_cloudy::A1
    qt_cloudy::A1
    th_cloudy::A1
    thl_cloudy::A1
    Hvar_rain_dt::A1
    QTvar_rain_dt::A1
    HQTcov_rain_dt::A1
    qt_tendency_rain_formation::A1
    θ_liq_ice_tendency_rain_formation::A1
    function EnvironmentThermodynamics(namelist, grid::Grid)
        quadrature_order = parse_namelist(namelist, "thermodynamics", "quadrature_order"; default = 3)
        quadrature_type = parse_namelist(namelist, "thermodynamics", "quadrature_type"; default = "gaussian")

        qt_dry = center_field(grid)
        th_dry = center_field(grid)
        thv_dry = center_field(grid)

        t_cloudy = center_field(grid)
        qv_cloudy = center_field(grid)
        qt_cloudy = center_field(grid)
        th_cloudy = center_field(grid)
        thl_cloudy = center_field(grid)

        Hvar_rain_dt = center_field(grid)
        QTvar_rain_dt = center_field(grid)
        HQTcov_rain_dt = center_field(grid)

        qt_tendency_rain_formation = center_field(grid)
        θ_liq_ice_tendency_rain_formation = center_field(grid)
        A1 = typeof(qt_dry)
        return new{A1}(
            quadrature_order,
            quadrature_type,
            qt_dry,
            th_dry,
            thv_dry,
            t_cloudy,
            qv_cloudy,
            qt_cloudy,
            th_cloudy,
            thl_cloudy,
            Hvar_rain_dt,
            QTvar_rain_dt,
            HQTcov_rain_dt,
            qt_tendency_rain_formation,
            θ_liq_ice_tendency_rain_formation,
        )
    end
end

# Stochastic entrainment/detrainment closures:
struct NoneClosureType end
struct LogNormalClosureType end
struct SDEClosureType end

# Stochastic differential equation memory
Base.@kwdef mutable struct sde_struct{T}
    u0::Float64
    dt::Float64
end

# SurfaceMoninObukhovDry:
#     Needed for dry cases (qt=0). They have to be initialized with nonzero qtg for the
#     reference profiles. This surface subroutine sets the latent heat flux to zero
#     to prevent errors due to nonzero qtg in vars such as the obukhov_length.
# SurfaceSullivanPatton
#     Not fully implemented yet. Maybe not needed - Ignacio
struct SurfaceNone end
struct SurfaceFixedFlux end
struct SurfaceFixedCoeffs end
struct SurfaceMoninObukhov end
struct SurfaceMoninObukhovDry end
struct SurfaceSullivanPatton end

Base.@kwdef mutable struct SurfaceBase{T}
    zrough::Float64 = 0
    interactive_zrough::Bool = false
    Tsurface::Float64 = 0
    qsurface::Float64 = 0
    shf::Float64 = 0
    lhf::Float64 = 0
    cm::Float64 = 0
    ch::Float64 = 0
    cq::Float64 = 0
    bflux::Float64 = 0
    windspeed::Float64 = 0
    ustar::Float64 = 0
    rho_qtflux::Float64 = 0
    rho_hflux::Float64 = 0
    rho_uflux::Float64 = 0
    rho_vflux::Float64 = 0
    obukhov_length::Float64 = 0
    Ri_bulk_crit::Float64 = 0
    ustar_fixed::Bool = false
    ref_params::NamedTuple = NamedTuple()
end

function SurfaceBase(::Type{T}; namelist::Dict, ref_params) where {T}
    Ri_bulk_crit = namelist["turbulence"]["Ri_bulk_crit"]
    return SurfaceBase{T}(; Ri_bulk_crit, ref_params)
end

struct ForcingBaseType end
struct ForcingNone end
struct ForcingStandard end
struct ForcingDYCOMS_RF01 end
struct ForcingLES end

struct RadiationBaseType end
struct RadiationNone end
struct RadiationStandard end
struct RadiationDYCOMS_RF01 end
struct RadiationLES end

Base.@kwdef mutable struct LESData
    imin::Int = 0
    imax::Int = 0
    les_filename::String = nothing
end

Base.@kwdef mutable struct ForcingBase{T}
    subsidence::AbstractArray{Float64, 1} = zeros(1)
    dTdt::AbstractArray{Float64, 1} = zeros(1) # horizontal advection temperature tendency
    dqtdt::AbstractArray{Float64, 1} = zeros(1) # horizontal advection moisture tendency
    dtdt_hadv::AbstractArray{Float64, 1} = zeros(1)
    dtdt_nudge::AbstractArray{Float64, 1} = zeros(1)
    dtdt_fluc::AbstractArray{Float64, 1} = zeros(1)
    dqtdt_hadv::AbstractArray{Float64, 1} = zeros(1)
    dqtdt_nudge::AbstractArray{Float64, 1} = zeros(1)
    dqtdt_fluc::AbstractArray{Float64, 1} = zeros(1)
    u_nudge::AbstractArray{Float64, 1} = zeros(1)
    v_nudge::AbstractArray{Float64, 1} = zeros(1)
    apply_coriolis::Bool = false
    apply_subsidence::Bool = false
    coriolis_param::Float64 = 0
    ug::AbstractArray{Float64, 1} = zeros(1)
    vg::AbstractArray{Float64, 1} = zeros(1)
    nudge_tau::Float64 = 0.0 # default is set to a value that will break
    convert_forcing_prog_fp::Function = x -> x
end

force_type(::ForcingBase{T}) where {T} = T

Base.@kwdef mutable struct RadiationBase{T}
    dTdt::AbstractArray{Float64, 1} = zeros(1) # horizontal advection temperature tendency
    dqtdt::AbstractArray{Float64, 1} = zeros(1) # horizontal advection moisture tendency
    divergence::Float64 = 0
    alpha_z::Float64 = 0
    kappa::Float64 = 0
    F0::Float64 = 0
    F1::Float64 = 0
    f_rad::AbstractArray{Float64, 1} = zeros(1)
end

rad_type(::RadiationBase{T}) where {T} = T

Base.@kwdef mutable struct CasesBase{T}
    casename::String = "default_casename"
    inversion_option::String = "default_inversion_option"
    les_filename::String = "None"
    Sur::SurfaceBase
    Fo::ForcingBase
    Rad::RadiationBase
    rad_time::StepRangeLen = range(10, 360; length = 36) .* 60
    rad::AbstractMatrix{Float64} = zeros(1, 1)
    lhf0::Float64 = 0
    shf0::Float64 = 0
    LESDat::Union{LESData, Nothing} = nothing
end

CasesBase(case::T; kwargs...) where {T} = CasesBase{T}(; casename = string(nameof(T)), kwargs...)

function center_field_tridiagonal_matrix(grid::Grid)
    return LinearAlgebra.Tridiagonal(center_field(grid)[2:end], center_field(grid), center_field(grid)[1:(end - 1)])
end

mutable struct EDMF_PrognosticTKE{A1, A2, IE}
    KM::VariableDiagnostic
    KH::VariableDiagnostic
    Ri_bulk_crit::Float64
    zi::Float64
    n_updrafts::Int
    drag_sign::Int
    asp_label
    extrapolate_buoyancy::Bool
    surface_area::Float64
    max_area::Float64
    aspect_ratio::Float64
    tke_ed_coeff::Float64
    tke_diss_coeff::Float64
    static_stab_coeff::Float64
    lambda_stab::Float64
    minimum_area::Float64
    Rain::RainVariables
    RainPhys::RainPhysics
    UpdVar::UpdraftVariables
    UpdThermo::UpdraftThermodynamics
    EnvVar::EnvironmentVariables
    EnvThermo::EnvironmentThermodynamics
    entr_sc::A2
    press::A2
    detr_sc::A2
    sorting_function::A2
    b_mix::A2
    frac_turb_entr::A2
    nh_pressure::A2
    nh_pressure_b::A2
    nh_pressure_adv::A2
    nh_pressure_drag::A2
    asp_ratio::A2
    m::A2
    mixing_length::A1
    implicit_eqs::IE
    ae::A1
    rho_ae_KM::A1
    rho_ae_KH::A1
    horiz_K_eddy::A2
    area_surface_bc::A1
    w_surface_bc::A1
    h_surface_bc::A1
    qt_surface_bc::A1
    pressure_plume_spacing::A1
    massflux_tendency_h::A1
    massflux_tendency_qt::A1
    diffusive_tendency_h::A1
    diffusive_tendency_qt::A1
    massflux_h::A1
    massflux_qt::A1
    diffusive_flux_h::A1
    diffusive_flux_qt::A1
    diffusive_flux_u::A1
    diffusive_flux_v::A1
    massflux_tke::A1
    prandtl_nvec::A1
    prandtl_number::Float64
    mls::A1
    ml_ratio::A1
    l_entdet::A1
    b::A1
    wstar::Float64
    entr_surface_bc::Float64
    detr_surface_bc::Float64
    sde_model::sde_struct
    bg_closure::EnvBuoyGradClosure
    function EDMF_PrognosticTKE(namelist, grid::Grid, param_set::PS) where {PS}
        KM = VariableDiagnostic(grid, "half", "diffusivity", "m^2/s") # eddy viscosity
        KH = VariableDiagnostic(grid, "half", "viscosity", "m^2/s") # eddy diffusivity
        # get values from namelist
        prandtl_number = namelist["turbulence"]["prandtl_number_0"]
        Ri_bulk_crit = namelist["turbulence"]["Ri_bulk_crit"]
        zi = 0.0

        # Set the number of updrafts (1)
        n_updrafts = parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "updraft_number"; default = 1)

        pressure_func_drag_str = parse_namelist(
            namelist,
            "turbulence",
            "EDMF_PrognosticTKE",
            "pressure_closure_drag";
            default = "normalmode",
            valid_options = ["normalmode", "normalmode_signdf"],
        )

        if pressure_func_drag_str == "normalmode"
            drag_sign = false
        elseif pressure_func_drag_str == "normalmode_signdf"
            drag_sign = true
        end

        asp_label = parse_namelist(
            namelist,
            "turbulence",
            "EDMF_PrognosticTKE",
            "pressure_closure_asp_label";
            default = "const",
        )

        extrapolate_buoyancy =
            parse_namelist(namelist, "turbulence", "EDMF_PrognosticTKE", "extrapolate_buoyancy"; default = true)

        # Get values from namelist
        # set defaults at some point?
        surface_area = namelist["turbulence"]["EDMF_PrognosticTKE"]["surface_area"]
        max_area = namelist["turbulence"]["EDMF_PrognosticTKE"]["max_area"]
        # entrainment parameters
        # pressure parameters
        aspect_ratio = namelist["turbulence"]["EDMF_PrognosticTKE"]["aspect_ratio"]

        # mixing length parameters
        tke_ed_coeff = namelist["turbulence"]["EDMF_PrognosticTKE"]["tke_ed_coeff"]
        tke_diss_coeff = namelist["turbulence"]["EDMF_PrognosticTKE"]["tke_diss_coeff"]
        static_stab_coeff = namelist["turbulence"]["EDMF_PrognosticTKE"]["static_stab_coeff"]
        lambda_stab = namelist["turbulence"]["EDMF_PrognosticTKE"]["lambda_stab"] # Latent heat stability effect
        # Need to code up as namelist option?
        minimum_area = 1e-5

        # Create the class for rain
        Rain = RainVariables(namelist, grid)
        # Create the class for rain physics
        RainPhys = RainPhysics(grid)

        # Create the updraft variable class (major diagnostic and prognostic variables)
        UpdVar = UpdraftVariables(n_updrafts, namelist, grid)
        # Create the class for updraft thermodynamics
        UpdThermo = UpdraftThermodynamics(n_updrafts, grid)

        # Create the environment variable class (major diagnostic and prognostic variables)
        EnvVar = EnvironmentVariables(namelist, grid)
        # Create the class for environment thermodynamics
        EnvThermo = EnvironmentThermodynamics(namelist, grid)

        # Entrainment rates
        entr_sc = center_field(grid, n_updrafts)
        press = center_field(grid, n_updrafts)

        # Detrainment rates
        detr_sc = center_field(grid, n_updrafts)

        sorting_function = center_field(grid, n_updrafts)
        b_mix = center_field(grid, n_updrafts)

        # turbulent entrainment
        frac_turb_entr = center_field(grid, n_updrafts)

        # Pressure term in updraft vertical momentum equation
        nh_pressure = face_field(grid, n_updrafts)
        nh_pressure_b = face_field(grid, n_updrafts)
        nh_pressure_adv = face_field(grid, n_updrafts)
        nh_pressure_drag = face_field(grid, n_updrafts)
        asp_ratio = center_field(grid, n_updrafts)

        # Mass flux
        m = face_field(grid, n_updrafts)

        # mixing length
        implicit_eqs = (
            A_θq_gm = center_field_tridiagonal_matrix(grid),
            A_uv_gm = center_field_tridiagonal_matrix(grid),
            A_TKE = center_field_tridiagonal_matrix(grid),
            A_Hvar = center_field_tridiagonal_matrix(grid),
            A_QTvar = center_field_tridiagonal_matrix(grid),
            A_HQTcov = center_field_tridiagonal_matrix(grid),
            b_θ_liq_ice_gm = center_field(grid),
            b_q_tot_gm = center_field(grid),
            b_u_gm = center_field(grid),
            b_v_gm = center_field(grid),
            b_TKE = center_field(grid),
            b_Hvar = center_field(grid),
            b_QTvar = center_field(grid),
            b_HQTcov = center_field(grid),
        )
        mixing_length = center_field(grid)
        horiz_K_eddy = center_field(grid, n_updrafts)

        ae = center_field(grid)
        rho_ae_KM = face_field(grid)
        rho_ae_KH = face_field(grid)

        # Near-surface BC of updraft area fraction
        area_surface_bc = zeros(n_updrafts)
        w_surface_bc = zeros(n_updrafts)
        h_surface_bc = zeros(n_updrafts)
        qt_surface_bc = zeros(n_updrafts)
        pressure_plume_spacing = zeros(n_updrafts)

        # Mass flux tendencies of mean scalars (for output)
        massflux_tendency_h = center_field(grid)
        massflux_tendency_qt = center_field(grid)

        # (Eddy) diffusive tendencies of mean scalars (for output)
        diffusive_tendency_h = center_field(grid)
        diffusive_tendency_qt = center_field(grid)

        # Vertical fluxes for output
        massflux_h = face_field(grid)
        massflux_qt = face_field(grid)
        diffusive_flux_h = face_field(grid)
        diffusive_flux_qt = face_field(grid)
        diffusive_flux_u = face_field(grid)
        diffusive_flux_v = face_field(grid)
        massflux_tke = center_field(grid)

        # Initialize SDE parameters
        dt = parse_namelist(namelist, "time_stepping", "dt"; default = 1.0)
        closure = parse_namelist(
            namelist,
            "turbulence",
            "EDMF_PrognosticTKE",
            "stochastic",
            "closure";
            default = "none",
            valid_options = ["none", "lognormal", "sde"],
        )
        closure_type = if closure == "none"
            NoneClosureType
        elseif closure == "lognormal"
            LogNormalClosureType
        elseif closure == "sde"
            SDEClosureType
        else
            error("Something went wrong. Invalid stochastic closure type '$closure'")
        end
        sde_model = sde_struct{closure_type}(u0 = 1, dt = dt)

        bg_type = parse_namelist(
            namelist,
            "turbulence",
            "EDMF_PrognosticTKE",
            "env_buoy_grad";
            default = "Tan2018",
            valid_options = ["Tan2018", "Quadratures"],
        )
        bg_closure = if bg_type == "Tan2018"
            BuoyGradTan2018()
        else #if closure == "Quadratures"
            BuoyGradQuadratures()
            # else
            #     error("Something went wrong. Invalid environmental buoyancy gradient closure type '$bg_type'")
        end

        # Added by Ignacio : Length scheme in use (mls), and smooth min effect (ml_ratio)
        # Variable Prandtl number initialized as neutral value.
        ones_vec = center_field(grid)
        prandtl_nvec = prandtl_number .* ones_vec
        mls = center_field(grid)
        ml_ratio = center_field(grid)
        l_entdet = center_field(grid)
        b = center_field(grid)
        wstar = 0
        entr_surface_bc = 0
        detr_surface_bc = 0
        A1 = typeof(mixing_length)
        A2 = typeof(horiz_K_eddy)
        IE = typeof(implicit_eqs)
        return new{A1, A2, IE}(
            KM,
            KH,
            Ri_bulk_crit,
            zi,
            n_updrafts,
            drag_sign,
            asp_label,
            extrapolate_buoyancy,
            surface_area,
            max_area,
            aspect_ratio,
            tke_ed_coeff,
            tke_diss_coeff,
            static_stab_coeff,
            lambda_stab,
            minimum_area,
            Rain,
            RainPhys,
            UpdVar,
            UpdThermo,
            EnvVar,
            EnvThermo,
            entr_sc,
            press,
            detr_sc,
            sorting_function,
            b_mix,
            frac_turb_entr,
            nh_pressure,
            nh_pressure_b,
            nh_pressure_adv,
            nh_pressure_drag,
            asp_ratio,
            m,
            mixing_length,
            implicit_eqs,
            ae,
            rho_ae_KM,
            rho_ae_KH,
            horiz_K_eddy,
            area_surface_bc,
            w_surface_bc,
            h_surface_bc,
            qt_surface_bc,
            pressure_plume_spacing,
            massflux_tendency_h,
            massflux_tendency_qt,
            diffusive_tendency_h,
            diffusive_tendency_qt,
            massflux_h,
            massflux_qt,
            diffusive_flux_h,
            diffusive_flux_qt,
            diffusive_flux_u,
            diffusive_flux_v,
            massflux_tke,
            prandtl_nvec,
            prandtl_number,
            mls,
            ml_ratio,
            l_entdet,
            b,
            wstar,
            entr_surface_bc,
            detr_surface_bc,
            sde_model,
            bg_closure,
        )
    end
end
prandtl_number(edmf::EDMF_PrognosticTKE) = edmf.prandtl_number
diffusivity_m(edmf::EDMF_PrognosticTKE) = edmf.KM
diffusivity_h(edmf::EDMF_PrognosticTKE) = edmf.KH
Ri_bulk_crit(edmf::EDMF_PrognosticTKE) = edmf.Ri_bulk_crit
parameter_set(obj) = obj.param_set
