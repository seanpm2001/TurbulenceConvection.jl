import UnPack

import TurbulenceConvection
const TC = TurbulenceConvection

import Thermodynamics
const TD = Thermodynamics

import ClimaCore
const CC = ClimaCore
const CCG = CC.Geometry

import OrdinaryDiffEq
const ODE = OrdinaryDiffEq

import CLIMAParameters
const CPP = CLIMAParameters.Planet
const APS = CLIMAParameters.AbstractEarthParameterSet

#####
##### Fields
#####

##### Auxiliary fields

# Face & Center
aux_vars_ref_state(FT) = (; ref_state = (ρ0 = FT(0), α0 = FT(0), p0 = FT(0)))

# Center only
cent_aux_vars_gm_moisture(FT, ::TC.NonEquilibriumMoisture) = (;
    ∇q_liq_gm = FT(0),
    ∇q_ice_gm = FT(0),
    dqldt_rad = FT(0),
    dqidt_rad = FT(0),
    dqldt = FT(0),
    dqidt = FT(0),
    dqldt_hadv = FT(0),
    dqidt_hadv = FT(0),
    ql_nudge = FT(0),
    qi_nudge = FT(0),
    dqldt_fluc = FT(0),
    dqidt_fluc = FT(0),
)
cent_aux_vars_gm_moisture(FT, ::TC.EquilibriumMoisture) = NamedTuple()
cent_aux_vars_gm(FT, edmf) = (;
    ts = TC.thermo_state(FT, edmf.moisture_model),
    tke = FT(0),
    Hvar = FT(0),
    QTvar = FT(0),
    HQTcov = FT(0),
    q_liq = FT(0),
    q_ice = FT(0),
    RH = FT(0),
    s = FT(0),
    T = FT(0),
    buoy = FT(0),
    cloud_fraction = FT(0),
    H_third_m = FT(0),
    W_third_m = FT(0),
    QT_third_m = FT(0),
    # From RadiationBase
    dTdt_rad = FT(0), # horizontal advection temperature tendency
    dqtdt_rad = FT(0), # horizontal advection moisture tendency
    # From ForcingBase
    subsidence = FT(0), #Large-scale subsidence
    dTdt_hadv = FT(0), #Horizontal advection of temperature
    dqtdt_hadv = FT(0), #Horizontal advection of moisture
    H_nudge = FT(0), #Reference H profile for relaxation tendency
    qt_nudge = FT(0), #Reference qt profile for relaxation tendency
    dTdt_fluc = FT(0), #Vertical turbulent advection of temperature
    dqtdt_fluc = FT(0), #Vertical turbulent advection of moisture
    u_nudge = FT(0), #Reference u profile for relaxation tendency
    v_nudge = FT(0), #Reference v profile for relaxation tendency
    ug = FT(0), #Geostrophic u velocity
    vg = FT(0), #Geostrophic v velocity
    ∇θ_liq_ice_gm = FT(0),
    ∇q_tot_gm = FT(0),
    cent_aux_vars_gm_moisture(FT, edmf.moisture_model)...,
    θ_virt = FT(0),
    Ri = FT(0),
    θ_liq_ice = FT(0),
    q_tot = FT(0),
)
cent_aux_vars(FT, edmf) =
    (; aux_vars_ref_state(FT)..., cent_aux_vars_gm(FT, edmf)..., TC.cent_aux_vars_edmf(FT, edmf)...)

# Face only
face_aux_vars_gm_moisture(FT, ::TC.NonEquilibriumMoisture) = (; sgs_flux_q_liq = FT(0), sgs_flux_q_ice = FT(0))
face_aux_vars_gm_moisture(FT, ::TC.EquilibriumMoisture) = NamedTuple()
face_aux_vars_gm(FT, edmf) = (;
    massflux_s = FT(0),
    diffusive_flux_s = FT(0),
    total_flux_s = FT(0),
    f_rad = FT(0),
    sgs_flux_θ_liq_ice = FT(0),
    sgs_flux_q_tot = FT(0),
    face_aux_vars_gm_moisture(FT, edmf.moisture_model)...,
    sgs_flux_u = FT(0),
    sgs_flux_v = FT(0),
)
face_aux_vars(FT, edmf) =
    (; aux_vars_ref_state(FT)..., face_aux_vars_gm(FT, edmf)..., TC.face_aux_vars_edmf(FT, edmf)...)

##### Diagnostic fields

# Center only
cent_diagnostic_vars_gm(FT) = NamedTuple()
cent_diagnostic_vars(FT, edmf) = (; cent_diagnostic_vars_gm(FT)..., TC.cent_diagnostic_vars_edmf(FT, edmf)...)

# Face only
face_diagnostic_vars_gm(FT) = NamedTuple()
face_diagnostic_vars(FT, edmf) = (; face_diagnostic_vars_gm(FT)..., TC.face_diagnostic_vars_edmf(FT, edmf)...)

# Single value per column diagnostic variables
single_value_per_col_diagnostic_vars_gm(FT) = (;
    Tsurface = FT(0),
    shf = FT(0),
    lhf = FT(0),
    ustar = FT(0),
    wstar = FT(0),
    lwp_mean = FT(0),
    iwp_mean = FT(0),
    rwp_mean = FT(0),
    swp_mean = FT(0),
    cutoff_precipitation_rate = FT(0),
    cloud_base_mean = FT(0),
    cloud_top_mean = FT(0),
    cloud_cover_mean = FT(0),
)
single_value_per_col_diagnostic_vars(FT, edmf) =
    (; single_value_per_col_diagnostic_vars_gm(FT)..., TC.single_value_per_col_diagnostic_vars_edmf(FT, edmf)...)

##### Prognostic fields

# Center only
cent_prognostic_vars(::Type{FT}, local_geometry, edmf) where {FT} =
    (; cent_prognostic_vars_gm(FT, local_geometry, edmf)..., TC.cent_prognostic_vars_edmf(FT, edmf)...)
cent_prognostic_vars_gm_moisture(::Type{FT}, ::TC.NonEquilibriumMoisture) where {FT} = (; q_liq = FT(0), q_ice = FT(0))
cent_prognostic_vars_gm_moisture(::Type{FT}, ::TC.EquilibriumMoisture) where {FT} = NamedTuple()
cent_prognostic_vars_gm(::Type{FT}, local_geometry, edmf) where {FT} = (;
    u = FT(0),
    v = FT(0),
    ρθ_liq_ice = FT(0),
    ρq_tot = FT(0),
    # TODO: Change to:
    # uₕ = CCG.Covariant12Vector(CCG.UVVector(FT(0), FT(0)), local_geometry),
    # ρe = FT(0),
    cent_prognostic_vars_gm_moisture(FT, edmf.moisture_model)...,
)

# Face only
face_prognostic_vars(::Type{FT}, local_geometry, edmf) where {FT} =
    (; w = CCG.Covariant3Vector(FT(0)), TC.face_prognostic_vars_edmf(FT, local_geometry, edmf)...)

# TC.face_prognostic_vars_edmf(FT, edmf) = (;) # could also use this for empty model


#####
##### Methods
#####

####
#### Reference state
####

"""
    compute_ref_state!(
        state,
        grid::Grid,
        param_set::PS;
        ts_g,
    ) where {PS}

TODO: add better docs once the API converges

The reference profiles, given
 - `grid` the grid
 - `param_set` the parameter set
 - `ts_g` the surface reference state (a thermodynamic state)
"""
function compute_ref_state!(state, grid::TC.Grid, param_set::PS; ts_g) where {PS}
    p0_c = TC.center_ref_state(state).p0
    ρ0_c = TC.center_ref_state(state).ρ0
    α0_c = TC.center_ref_state(state).α0
    p0_f = TC.face_ref_state(state).p0
    ρ0_f = TC.face_ref_state(state).ρ0
    α0_f = TC.face_ref_state(state).α0
    compute_ref_state!(p0_c, ρ0_c, α0_c, p0_f, ρ0_f, α0_f, grid, param_set; ts_g)
end

function compute_ref_state!(
    p0_c::CC.Fields.Field,
    ρ0_c::CC.Fields.Field,
    α0_c::CC.Fields.Field,
    p0_f::CC.Fields.Field,
    ρ0_f::CC.Fields.Field,
    α0_f::CC.Fields.Field,
    grid::TC.Grid,
    param_set::PS;
    ts_g,
) where {PS}

    FT = eltype(grid)

    qtg = TD.total_specific_humidity(param_set, ts_g)
    θ_liq_ice_g = TD.liquid_ice_pottemp(param_set, ts_g)
    Pg = TD.air_pressure(param_set, ts_g)

    # We are integrating the log pressure so need to take the log of the
    # surface pressure
    logp = log(Pg)

    # Form a right hand side for integrating the hydrostatic equation to
    # determine the reference pressure
    function rhs(logp, u, z)
        p_ = exp(logp)
        ts = TD.PhaseEquil_pθq(param_set, p_, θ_liq_ice_g, qtg)
        R_m = TD.gas_constant_air(param_set, ts)
        T = TD.air_temperature(param_set, ts)
        return -FT(CPP.grav(param_set)) / (T * R_m)
    end

    # Perform the integration
    z_span = (grid.zmin, grid.zmax)
    @info "z_span = $z_span"
    prob = ODE.ODEProblem(rhs, logp, z_span)
    sol = ODE.solve(prob, ODE.Tsit5(), reltol = 1e-12, abstol = 1e-12)

    parent(p0_f) .= sol.(vec(grid.zf))
    parent(p0_c) .= sol.(vec(grid.zc))

    p0_f .= exp.(p0_f)
    p0_c .= exp.(p0_c)

    # Compute reference state thermodynamic profiles
    @inbounds for k in TC.real_center_indices(grid)
        ts = TD.PhaseEquil_pθq(param_set, p0_c[k], θ_liq_ice_g, qtg)
        α0_c[k] = TD.specific_volume(param_set, ts)
    end

    @inbounds for k in TC.real_face_indices(grid)
        ts = TD.PhaseEquil_pθq(param_set, p0_f[k], θ_liq_ice_g, qtg)
        α0_f[k] = TD.specific_volume(param_set, ts)
    end

    ρ0_f .= 1 ./ α0_f
    ρ0_c .= 1 ./ α0_c
    return nothing
end

function set_thermo_state!(state, grid, moisture_model, param_set)
    ts_gm = TC.center_aux_grid_mean(state).ts
    prog_gm = TC.center_prog_grid_mean(state)
    aux_gm = TC.center_aux_grid_mean(state)
    p0_c = TC.center_ref_state(state).p0
    ρ0_c = TC.center_ref_state(state).ρ0
    @inbounds for k in TC.real_center_indices(grid)
        aux_gm.θ_liq_ice[k] = prog_gm.ρθ_liq_ice[k] / ρ0_c[k]
        aux_gm.q_tot[k] = prog_gm.ρq_tot[k] / ρ0_c[k]
        thermo_args = if moisture_model isa TC.EquilibriumMoisture
            ()
        elseif moisture_model isa TC.NonEquilibriumMoisture
            (prog_gm.q_liq[k], prog_gm.q_ice[k])
        else
            error("Something went wrong. The moisture_model options are equilibrium or nonequilibrium")
        end
        ts_gm[k] = TC.thermo_state_pθq(param_set, p0_c[k], aux_gm.θ_liq_ice[k], aux_gm.q_tot[k], thermo_args...)
    end
    return nothing
end

function assign_thermo_aux!(state, grid, moisture_model, param_set)
    ρ0_c = TC.center_ref_state(state).ρ0
    aux_gm = TC.center_aux_grid_mean(state)
    prog_gm = TC.center_prog_grid_mean(state)
    ts_gm = TC.center_aux_grid_mean(state).ts
    @inbounds for k in TC.real_center_indices(grid)
        aux_gm.θ_liq_ice[k] = prog_gm.ρθ_liq_ice[k] / ρ0_c[k]
        aux_gm.q_tot[k] = prog_gm.ρq_tot[k] / ρ0_c[k]
        ts = ts_gm[k]
        aux_gm.q_liq[k] = TD.liquid_specific_humidity(param_set, ts)
        aux_gm.q_ice[k] = TD.ice_specific_humidity(param_set, ts)
        aux_gm.T[k] = TD.air_temperature(param_set, ts)
        ρ = TD.air_density(param_set, ts)
        aux_gm.buoy[k] = TC.buoyancy_c(param_set, ρ0_c[k], ρ)
        aux_gm.RH[k] = TD.relative_humidity(param_set, ts)
    end
    return
end

function ∑stoch_tendencies!(tendencies::FV, prog::FV, params::NT, t::Real) where {NT, FV <: CC.Fields.FieldVector}
    UnPack.@unpack edmf, grid, param_set, case, aux, TS = params

    state = TC.State(prog, aux, tendencies)
    surf = get_surface(case.surf_params, grid, state, t, param_set)

    # set all tendencies to zero
    tends_face = tendencies.face
    tends_cent = tendencies.cent
    parent(tends_face) .= 0
    parent(tends_cent) .= 0

    # compute updraft stochastic tendencies
    TC.compute_up_stoch_tendencies!(edmf, grid, state, param_set, surf)
end

# Compute the sum of tendencies for the scheme
function ∑tendencies!(tendencies::FV, prog::FV, params::NT, t::Real) where {NT, FV <: CC.Fields.FieldVector}
    UnPack.@unpack edmf, precip_model, grid, param_set, case, aux, TS = params

    state = TC.State(prog, aux, tendencies)

    set_thermo_state!(state, grid, edmf.moisture_model, param_set)

    # TODO: where should this live?
    aux_gm = TC.center_aux_grid_mean(state)
    ts_gm = aux_gm.ts
    @inbounds for k in TC.real_center_indices(grid)
        aux_gm.θ_virt[k] = TD.virtual_pottemp(param_set, ts_gm[k])
    end

    Δt = TS.dt
    surf = get_surface(case.surf_params, grid, state, t, param_set)
    force = case.Fo
    radiation = case.Rad

    TC.affect_filter!(edmf, grid, state, param_set, surf, case.casename, t)

    # Update aux / pre-tendencies filters. TODO: combine these into a function that minimizes traversals
    # Some of these methods should probably live in `compute_tendencies`, when written, but we'll
    # treat them as auxiliary variables for now, until we disentangle the tendency computations.
    Cases.update_forcing(case, grid, state, t, param_set)
    Cases.update_radiation(case.Rad, grid, state, t, param_set)

    TC.update_aux!(edmf, grid, state, surf, param_set, t, Δt)

    tends_face = tendencies.face
    tends_cent = tendencies.cent
    parent(tends_face) .= 0
    parent(tends_cent) .= 0
    # compute tendencies

    en_thermo = edmf.en_thermo

    # compute tendencies
    # causes division error in dry bubble first time step
    TC.compute_precipitation_formation_tendencies(grid, state, edmf, precip_model, Δt, param_set)
    TC.microphysics(en_thermo, grid, state, edmf, precip_model, Δt, param_set)
    TC.compute_precipitation_sink_tendencies(precip_model, edmf, grid, state, param_set, Δt)
    TC.compute_precipitation_advection_tendencies(precip_model, edmf, grid, state, param_set)

    TC.compute_turbconv_tendencies!(edmf, grid, state, param_set, surf, Δt)
    compute_gm_tendencies!(edmf, grid, state, surf, radiation, force, param_set)

    return nothing
end

function compute_gm_tendencies!(
    edmf::TC.EDMFModel,
    grid::TC.Grid,
    state::TC.State,
    surf::TC.SurfaceBase,
    radiation::TC.RadiationBase,
    force::TC.ForcingBase,
    param_set::APS,
)
    tendencies_gm = TC.center_tendencies_grid_mean(state)
    kc_toa = TC.kc_top_of_atmos(grid)
    kf_surf = TC.kf_surface(grid)
    FT = eltype(grid)
    prog_gm = TC.center_prog_grid_mean(state)
    aux_gm = TC.center_aux_grid_mean(state)
    aux_gm_f = TC.face_aux_grid_mean(state)
    ∇θ_liq_ice_gm = TC.center_aux_grid_mean(state).∇θ_liq_ice_gm
    ∇q_tot_gm = TC.center_aux_grid_mean(state).∇q_tot_gm
    aux_en = TC.center_aux_environment(state)
    aux_en_f = TC.face_aux_environment(state)
    aux_up = TC.center_aux_updrafts(state)
    aux_bulk = TC.center_aux_bulk(state)
    ρ0_f = TC.face_ref_state(state).ρ0
    p0_c = TC.center_ref_state(state).p0
    α0_c = TC.center_ref_state(state).α0
    ρ0_c = TC.center_ref_state(state).ρ0
    aux_tc = TC.center_aux_turbconv(state)
    ts_gm = TC.center_aux_grid_mean(state).ts

    θ_liq_ice_gm_toa = aux_gm.θ_liq_ice[kc_toa]
    q_tot_gm_toa = aux_gm.q_tot[kc_toa]
    RBθ = CCO.RightBiasedC2F(; top = CCO.SetValue(θ_liq_ice_gm_toa))
    RBq = CCO.RightBiasedC2F(; top = CCO.SetValue(q_tot_gm_toa))
    wvec = CC.Geometry.WVector
    ∇c = CCO.DivergenceF2C()
    @. ∇θ_liq_ice_gm = ∇c(wvec(RBθ(aux_gm.θ_liq_ice)))
    @. ∇q_tot_gm = ∇c(wvec(RBq(aux_gm.q_tot)))

    if edmf.moisture_model isa TC.NonEquilibriumMoisture
        ∇q_liq_gm = TC.center_aux_grid_mean(state).∇q_liq_gm
        ∇q_ice_gm = TC.center_aux_grid_mean(state).∇q_ice_gm
        q_liq_gm_toa = prog_gm.q_liq[kc_toa]
        q_ice_gm_toa = prog_gm.q_ice[kc_toa]
        RBq_liq = CCO.RightBiasedC2F(; top = CCO.SetValue(q_liq_gm_toa))
        RBq_ice = CCO.RightBiasedC2F(; top = CCO.SetValue(q_ice_gm_toa))
        @. ∇q_liq_gm = ∇c(wvec(RBq(prog_gm.q_liq)))
        @. ∇q_ice_gm = ∇c(wvec(RBq(prog_gm.q_ice)))
    end

    # Apply forcing and radiation
    @inbounds for k in TC.real_center_indices(grid)
        Π = TD.exner(param_set, ts_gm[k])

        # Coriolis
        if force.apply_coriolis
            tendencies_gm.u[k] -= force.coriolis_param * (aux_gm.vg[k] - prog_gm.v[k])
            tendencies_gm.v[k] += force.coriolis_param * (aux_gm.ug[k] - prog_gm.u[k])
        end
        # LS Subsidence
        tendencies_gm.ρθ_liq_ice[k] -= ρ0_c[k] * ∇θ_liq_ice_gm[k] * aux_gm.subsidence[k]
        tendencies_gm.ρq_tot[k] -= ρ0_c[k] * ∇q_tot_gm[k] * aux_gm.subsidence[k]
        if edmf.moisture_model isa TC.NonEquilibriumMoisture
            tendencies_gm.q_liq[k] -= ∇q_liq_gm[k] * aux_gm.subsidence[k]
            tendencies_gm.q_ice[k] -= ∇q_ice_gm[k] * aux_gm.subsidence[k]
        end
        # Radiation
        if TC.rad_type(radiation) <: Union{TC.RadiationDYCOMS_RF01, TC.RadiationLES, TC.RadiationTRMM_LBA}
            tendencies_gm.ρθ_liq_ice[k] += ρ0_c[k] * aux_gm.dTdt_rad[k] / Π
        end
        # LS advection
        tendencies_gm.ρq_tot[k] += ρ0_c[k] * aux_gm.dqtdt_hadv[k]
        if !(TC.force_type(force) <: TC.ForcingDYCOMS_RF01)
            tendencies_gm.ρθ_liq_ice[k] += ρ0_c[k] * aux_gm.dTdt_hadv[k] / Π
        end
        if edmf.moisture_model isa TC.NonEquilibriumMoisture
            tendencies_gm.q_liq[k] += aux_gm.dqldt[k]
            tendencies_gm.q_ice[k] += aux_gm.dqidt[k]
        end

        # LES specific forcings
        if TC.force_type(force) <: TC.ForcingLES
            H_fluc = aux_gm.dTdt_fluc[k] / Π

            gm_U_nudge_k = (aux_gm.u_nudge[k] - prog_gm.u[k]) / force.nudge_tau
            gm_V_nudge_k = (aux_gm.v_nudge[k] - prog_gm.v[k]) / force.nudge_tau

            Γᵣ = TC.compute_les_Γᵣ(grid.zc[k])
            gm_H_nudge_k = Γᵣ * (aux_gm.H_nudge[k] - aux_gm.θ_liq_ice[k])
            gm_q_tot_nudge_k = Γᵣ * (aux_gm.qt_nudge[k] - aux_gm.q_tot[k])
            if edmf.moisture_model isa TC.NonEquilibriumMoisture
                gm_q_liq_nudge_k = Γᵣ * (aux_gm.ql_nudge[k] - prog_gm.q_liq[k])
                gm_q_ice_nudge_k = Γᵣ * (aux_gm.qi_nudge[k] - prog_gm.q_ice[k])
            end

            tendencies_gm.ρθ_liq_ice[k] += ρ0_c[k] * (gm_H_nudge_k + H_fluc)
            tendencies_gm.ρq_tot[k] += ρ0_c[k] * (gm_q_tot_nudge_k + aux_gm.dqtdt_fluc[k])
            tendencies_gm.u[k] += gm_U_nudge_k
            tendencies_gm.v[k] += gm_V_nudge_k
            if edmf.moisture_model isa TC.NonEquilibriumMoisture
                tendencies_gm.q_liq[k] += aux_gm.dqldt_hadv[k] + gm_q_liq_nudge_k + aux_gm.dqldt_fluc[k]
                tendencies_gm.q_ice[k] += aux_gm.dqidt_hadv[k] + gm_q_ice_nudge_k + aux_gm.dqidt_fluc[k]
            end
        end

        # Apply precipitation tendencies
        tendencies_gm.ρq_tot[k] +=
            ρ0_c[k] * (
                aux_bulk.qt_tendency_precip_formation[k] +
                aux_en.qt_tendency_precip_formation[k] +
                aux_tc.qt_tendency_precip_sinks[k]
            )
        tendencies_gm.ρθ_liq_ice[k] +=
            ρ0_c[k] * (
                aux_bulk.θ_liq_ice_tendency_precip_formation[k] +
                aux_en.θ_liq_ice_tendency_precip_formation[k] +
                aux_tc.θ_liq_ice_tendency_precip_sinks[k]
            )
        if edmf.moisture_model isa TC.NonEquilibriumMoisture
            tendencies_gm.q_liq[k] += aux_bulk.ql_tendency_precip_formation[k] + aux_en.ql_tendency_precip_formation[k]
            tendencies_gm.q_ice[k] += aux_bulk.qi_tendency_precip_formation[k] + aux_en.qi_tendency_precip_formation[k]
        end
    end

    TC.compute_sgs_flux!(edmf, grid, state, surf)

    sgs_flux_θ_liq_ice = aux_gm_f.sgs_flux_θ_liq_ice
    sgs_flux_q_tot = aux_gm_f.sgs_flux_q_tot
    sgs_flux_u = aux_gm_f.sgs_flux_u
    sgs_flux_v = aux_gm_f.sgs_flux_v
    # apply surface BC as SGS flux at lowest level
    sgs_flux_θ_liq_ice[kf_surf] = surf.ρθ_liq_ice_flux
    sgs_flux_q_tot[kf_surf] = surf.ρq_tot_flux
    sgs_flux_u[kf_surf] = surf.ρu_flux
    sgs_flux_v[kf_surf] = surf.ρv_flux

    tends_ρθ_liq_ice = tendencies_gm.ρθ_liq_ice
    tends_ρq_tot = tendencies_gm.ρq_tot
    tends_u = tendencies_gm.u
    tends_v = tendencies_gm.v

    ∇sgs = CCO.DivergenceF2C()

    @. tends_ρθ_liq_ice += -∇sgs(wvec(sgs_flux_θ_liq_ice))
    @. tends_ρq_tot += -∇sgs(wvec(sgs_flux_q_tot))
    @. tends_u += -α0_c * ∇sgs(wvec(sgs_flux_u))
    @. tends_v += -α0_c * ∇sgs(wvec(sgs_flux_v))

    if edmf.moisture_model isa TC.NonEquilibriumMoisture
        sgs_flux_q_liq = aux_gm_f.sgs_flux_q_liq
        sgs_flux_q_ice = aux_gm_f.sgs_flux_q_ice
        sgs_flux_q_liq[kf_surf] = surf.ρq_liq_flux
        sgs_flux_q_ice[kf_surf] = surf.ρq_ice_flux
        tends_q_liq = tendencies_gm.q_liq
        tends_q_ice = tendencies_gm.q_ice
        @. tends_q_liq += -α0_c * ∇sgs(wvec(sgs_flux_q_liq))
        @. tends_q_ice += -α0_c * ∇sgs(wvec(sgs_flux_q_ice))
    end

    return nothing
end
