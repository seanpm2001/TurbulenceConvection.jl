#### Entrainment-Detrainment kernels

function compute_turbulent_entrainment(c_γ::FT, a_up::FT, w_up::FT, tke::FT, H_up::FT) where {FT}

    ε_turb = if w_up * a_up > 0
        2 * c_γ * sqrt(max(tke, 0)) / (w_up * H_up)
    else
        FT(0)
    end

    return ε_turb
end

function compute_inverse_timescale(εδ_model, b_up::FT, b_en::FT, w_up::FT, w_en::FT, tke::FT) where {FT}
    Δb = b_up - b_en
    Δw = get_Δw(εδ_model, w_up, w_en)
    c_λ = εδ_params(εδ_model).c_λ

    l_1 = c_λ * abs(Δb / (sqrt(abs(tke)) + eps(FT)))
    l_2 = abs(Δb / Δw)
    l = SA.SVector(l_1, l_2)
    return lamb_smooth_minimum(l, FT(0.1))
end

function get_Δw(εδ_model, w_up::FT, w_en::FT) where {FT}
    Δw = w_up - w_en
    Δw += copysign(FT(εδ_params(εδ_model).w_min), Δw)
    return Δw
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::BuoyVelEntrDimScale,
) where {FT}
    Δw = get_Δw(εδ_model, w_up, w_en)
    λ = compute_inverse_timescale(εδ_model, b_up, b_en, w_up, w_en, tke)
    return (λ / Δw)
end


function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::InvScaleHeightEntrDimScale,
) where {FT}
    return (1 / ref_H)
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::InvZEntrDimScale,
) where {FT}
    return (1 / zc_i)
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::InvMeterEntrDimScale,
) where {FT}
    return FT(1)
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::PosMassFluxGradDimScale,
) where {FT}
    return max(∂lnM∂z, FT(0))
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::NegMassFluxGradDimScale,
) where {FT}
    return abs(min(∂lnM∂z, FT(0)))
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::AbsMassFluxGradDimScale,
) where {FT}
    return abs(∂lnM∂z)
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::BOverWDimScale,
) where {FT}
    Δb = b_up - b_en
    Δw = get_Δw(εδ_model, w_up, w_en)

    if Δb > 0
        return abs(Δb / (Δw + eps(FT)))
    else
        return 0.0
    end
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::WOverHeightDimScale,
) where {FT}
    Δw = get_Δw(εδ_model, w_up, w_en)
    return (Δw / zc_i)
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::BOverSqrtTKEDimScale,
) where {FT}
    Δb = b_up - b_en
    return abs(Δb / sqrt(abs(tke) + 1e-3)) * 1e-3
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::SqrtBOverZDimScale,
) where {FT}
    Δb = b_up - b_en
    if Δb > 0
        return sqrt(abs(Δb / zc_i)) * 3e-3
    else
        return 0.0
    end
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::TKEBWDimScale,
) where {FT}
    Δb = b_up - b_en
    Δw = get_Δw(εδ_model, w_up, w_en)
    return abs((tke * Δb) / (Δw^3))
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::DwDzDimScale,
) where {FT}
    if ∂w∂z < 0
        return abs(∂w∂z)
    else
        return 0.0
    end
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::DmDzOverRhoaDimScale,
) where {FT}
    if ∂M∂z_ρa < 0
        return abs(∂M∂z_ρa)
    else
        return 0.0
    end
end

function entrainment_dim_scale(
    εδ_model,
    b_up::FT,
    b_en::FT,
    w_up::FT,
    w_en::FT,
    tke::FT,
    zc_i::FT,
    ref_H::FT,
    ∂lnM∂z::FT,
    ∂M∂z::FT,
    ∂w∂z::FT,
    ∂M∂z_ρa::FT,
    ::MassFluxGradDimScale,
) where {FT}
    if ∂M∂z < 0
        return abs(∂M∂z)
    else
        return 0.0
    end
end

"""A convenience wrapper for entrainment_dim_scale"""
function entrainment_dim_scale(εδ_model, εδ_vars, dim_scale)
    return entrainment_dim_scale(
        εδ_model,
        εδ_vars.b_up,
        εδ_vars.b_en,
        εδ_vars.w_up,
        εδ_vars.w_en,
        εδ_vars.tke_en,
        εδ_vars.zc_i,
        εδ_vars.ref_H,
        εδ_vars.∂lnM∂z,
        εδ_vars.∂M∂z,
        εδ_vars.∂w∂z,
        εδ_vars.∂M∂z_ρa,
        dim_scale,
    )
end

"""
    εδ_dyn(εδ_model, εδ_vars, entr_dim_scale, detr_dim_scale, ε_nondim, δ_nondim)

Returns the fractional dynamical entrainment and detrainment rates [1/m] given non-dimensional rates

Parameters:
 - `εδ_model`       :: entrainment-detrainment model
 - `εδ_vars`        :: structure containing variables
 - `entr_dim_scale` :: type of dimensional fractional entrainment scale
 - `detr_dim_scale` :: type of dimensional fractional detrainment scale
 - `ε_nondim`       :: nondimensional fractional entrainment
 - `δ_nondim`       :: nondimensional fractional detrainment
"""
function εδ_dyn(εδ_model, εδ_vars, entr_dim_scale, detr_dim_scale, ε_nondim, δ_nondim)
    FT = eltype(εδ_vars.q_cond_up)
    ε_dim_scale = entrainment_dim_scale(εδ_model, εδ_vars, entr_dim_scale)
    δ_dim_scale = entrainment_dim_scale(εδ_model, εδ_vars, detr_dim_scale)

    area_limiter = max_area_limiter(εδ_model, εδ_vars.max_area, εδ_vars.a_up)
    min_limiter = min_area_limiter(εδ_model, εδ_vars.a_up)

    ε_dim_scale = min(ε_dim_scale, 1.0)
    δ_dim_scale = min(δ_dim_scale, 1.0)



    entr_nondim_norm_factor = εδ_params(εδ_model).entr_nondim_norm_factor
    detr_nondim_norm_factor = εδ_params(εδ_model).detr_nondim_norm_factor

    ε_dyn = ε_dim_scale * (entr_nondim_norm_factor * ε_nondim)
    δ_dyn = δ_dim_scale * (detr_nondim_norm_factor * δ_nondim)

    if εδ_params(εδ_model).limit_min_area
        ε_dyn += max(δ_dyn, ε_dyn) * min_limiter
    end
    δ_dyn += max(ε_dyn, δ_dyn) * area_limiter

    return ε_dyn, δ_dyn
end

"""
    entr_detr(εδ_model, εδ_vars, entr_dim_scale, detr_dim_scale)

Returns the fractional dynamical entrainment and detrainment rates [1/m],
as well as the turbulent entrainment rate

Parameters:
 - `εδ_model`       :: type of non-dimensional model for entrainment/detrainment
 - `εδ_vars`        :: structure containing variables
 - `entr_dim_scale` :: type of dimensional fractional entrainment scale
 - `detr_dim_scale` :: type of dimensional fractional detrainment scale
"""
function entr_detr(εδ_model, εδ_vars, entr_dim_scale, detr_dim_scale)
    FT = eltype(εδ_vars.q_cond_up)

    # fractional entrainment / detrainment
    ε_nondim, δ_nondim = non_dimensional_function(εδ_model, εδ_vars)
    ε_dyn, δ_dyn = εδ_dyn(εδ_model, εδ_vars, entr_dim_scale, detr_dim_scale, ε_nondim, δ_nondim)

    return EntrDetr{FT}(ε_dyn, δ_dyn, ε_nondim, δ_nondim)
end

##### Compute entr detr
function compute_turb_entr!(state::State, grid::Grid, edmf::EDMFModel)
    FT = float_type(state)
    N_up = n_updrafts(edmf)
    aux_up = center_aux_updrafts(state)
    aux_up_f = face_aux_updrafts(state)
    aux_en = center_aux_environment(state)
    aux_tc = center_aux_turbconv(state)
    w_up_c = aux_tc.w_up_c
    plume_scale_height = map(1:N_up) do i
        compute_plume_scale_height(grid, state, edmf.H_up_min, i)
    end
    Ic = CCO.InterpolateF2C()
    ∇c = CCO.DivergenceF2C()
    LB = CCO.LeftBiasedC2F(; bottom = CCO.SetValue(FT(0)))
    @inbounds for i in 1:N_up
        w_up = aux_up_f[i].w
        @. w_up_c = Ic(w_up)
        @inbounds for k in real_center_indices(grid)
            if aux_up[i].area[k] > edmf.minimum_area
                aux_up[i].frac_turb_entr[k] = compute_turbulent_entrainment(
                    εδ_params(edmf.entr_closure).c_γ,
                    aux_up[i].area[k],
                    w_up_c[k],
                    aux_en.tke[k],
                    plume_scale_height[i],
                )
            else
                aux_up[i].frac_turb_entr[k] = 0.0
            end
        end
    end
end

function compute_phys_entr_detr!(
    state::State,
    grid::Grid,
    edmf::EDMFModel,
    param_set::APS,
    surf::SurfaceBase,
    Δt::Real,
    εδ_closure::EntrNone,
)
    return nothing
end

##### Compute physical entr detr
function compute_phys_entr_detr!(
    state::State,
    grid::Grid,
    edmf::EDMFModel,
    param_set::APS,
    surf::SurfaceBase,
    Δt::Real,
    εδ_closure::AbstractEntrDetrModel,
)
    FT = float_type(state)
    N_up = n_updrafts(edmf)
    aux_up = center_aux_updrafts(state)
    prog_up = center_prog_updrafts(state)
    aux_up_f = face_aux_updrafts(state)
    aux_en = center_aux_environment(state)
    aux_en_f = face_aux_environment(state)
    prog_gm_f = face_prog_grid_mean(state)
    prog_gm = center_prog_grid_mean(state)
    aux_gm = center_aux_grid_mean(state)
    aux_tc = center_aux_turbconv(state)
    p_c = aux_gm.p
    ρ_c = prog_gm.ρ
    g::FT = TCP.grav(param_set)
    w_up_c = aux_tc.w_up_c
    w_en_c = aux_tc.w_en_c
    wvec = CC.Geometry.WVector
    max_area = edmf.max_area
    plume_scale_height = map(1:N_up) do i
        compute_plume_scale_height(grid, state, edmf.H_up_min, i)
    end
    Ic = CCO.InterpolateF2C()
    ∇c = CCO.DivergenceF2C()
    LB = CCO.LeftBiasedC2F(; bottom = CCO.SetValue(FT(0)))
    @inbounds for i in 1:N_up
        # compute ∇m at cell centers
        a_up = aux_up[i].area
        w_up = aux_up_f[i].w
        Π_groups = aux_up[i].Π_groups
        w_en = aux_en_f.w
        w_gm = prog_gm_f.w
        @. w_up_c = Ic(w_up)
        @. w_en_c = Ic(w_en)
        @inbounds for k in real_center_indices(grid)
            # entrainment

            q_cond_up = TD.condensate(TD.PhasePartition(aux_up[i].q_tot[k], aux_up[i].q_liq[k], aux_up[i].q_ice[k]))
            q_cond_en = TD.condensate(TD.PhasePartition(aux_en.q_tot[k], aux_en.q_liq[k], aux_en.q_ice[k]))

            if aux_up[i].area[k] > edmf.minimum_area
                εδ_model_vars = (;
                    q_cond_up = q_cond_up, # updraft condensate (liquid water + ice)
                    q_cond_en = q_cond_en, # environment condensate (liquid water + ice)
                    w_up = w_up_c[k], # updraft vertical velocity
                    w_en = w_en_c[k], # environment vertical velocity
                    b_up = aux_up[i].buoy[k], # updraft buoyancy
                    b_en = aux_en.buoy[k], # environment buoyancy
                    tke_gm = aux_gm.tke[k], # grid mean tke
                    tke_en = aux_en.tke[k], # environment tke
                    a_up = aux_up[i].area[k], # updraft area fraction
                    a_en = aux_en.area[k], # environment area fraction
                    H_up = plume_scale_height[i], # plume scale height
                    ref_H = p_c[k] / (ρ_c[k] * g), # reference state scale height
                    RH_up = aux_up[i].RH[k], # updraft relative humidity
                    RH_en = aux_en.RH[k], # environment relative humidity
                    max_area = max_area, # maximum updraft area
                    zc_i = FT(grid.zc[k].z), # vertical coordinate
                    ∂lnM∂z = aux_tc.∂lnM∂z[k], # ln(massflux) gradient
                    Δt = Δt, # Model time step
                    ε_nondim = aux_up[i].ε_nondim[k], # nondimensional fractional dynamical entrainment
                    δ_nondim = aux_up[i].δ_nondim[k], # nondimensional fractional dynamical detrainment
                    ∂M∂z = aux_tc.∂M∂z[k],
                    entr_Π_subset = entrainment_Π_subset(edmf), # indices of Pi groups to include
                    ∂w∂z = aux_tc.∂w∂z[k],
                    ∂M∂z_ρa = aux_tc.∂M∂z_ρa[k],
                )

                # store pi groups for output
                Π = non_dimensional_groups(εδ_closure, εδ_model_vars)
                @assert length(Π) == n_Π_groups(edmf)
                for Π_i in 1:length(entrainment_Π_subset(edmf))
                    Π_groups[Π_i][k] = Π[Π_i]
                end

                # update fractional and turbulent entr/detr
                if εδ_closure isa PrognosticNoisyRelaxationProcess
                    # fractional dynamical entrainment from prognostic state
                    ε_nondim, δ_nondim = prog_up[i].ε_nondim[k], prog_up[i].δ_nondim[k]
                    mean_model = εδ_closure.mean_model
                    ε_dyn, δ_dyn =
                        εδ_dyn(mean_model, εδ_model_vars, edmf.entr_dim_scale, edmf.detr_dim_scale, ε_nondim, δ_nondim)
                    # turbulent & mean nondimensional entrainment
                    ε_nondim, δ_nondim = non_dimensional_function(mean_model, εδ_model_vars)
                    ε_dyn, δ_dyn =
                        εδ_dyn(mean_model, εδ_model_vars, edmf.entr_dim_scale, edmf.detr_dim_scale, ε_nondim, δ_nondim)
                else
                    # fractional, turbulent & nondimensional entrainment
                    ε_nondim, δ_nondim = non_dimensional_function(εδ_closure, εδ_model_vars)
                    ε_dyn, δ_dyn =
                        εδ_dyn(εδ_closure, εδ_model_vars, edmf.entr_dim_scale, edmf.detr_dim_scale, ε_nondim, δ_nondim)
                end

                if edmf.entrainment_type isa FractionalEntrModel

                    aux_up[i].entr_sc[k] = ε_dyn
                    aux_up[i].detr_sc[k] = δ_dyn
                    # update nondimensional entr/detr
                    aux_up[i].ε_nondim[k] = ε_nondim
                    aux_up[i].δ_nondim[k] = δ_nondim

                    aux_up[i].entr_rate_inv_s[k] = w_up_c[k] * ε_dyn
                    aux_up[i].detr_rate_inv_s[k] = w_up_c[k] * δ_dyn

                elseif edmf.entrainment_type isa TotalRateEntrModel
                    FT = eltype(εδ_model_vars.q_cond_up)
                    aux_up[i].entr_sc[k] = ε_dyn / (w_up_c[k] + eps(FT)) # fractional rates
                    aux_up[i].detr_sc[k] = δ_dyn / (w_up_c[k] + eps(FT)) # fractional rates
                    # update nondimensional entr/detr
                    aux_up[i].ε_nondim[k] = ε_nondim
                    aux_up[i].δ_nondim[k] = δ_nondim

                    aux_up[i].entr_rate_inv_s[k] = ε_dyn
                    aux_up[i].detr_rate_inv_s[k] = δ_dyn
                end

            else
                aux_up[i].entr_sc[k] = 0.0
                aux_up[i].detr_sc[k] = 0.0
                aux_up[i].ε_nondim[k] = 0.0
                aux_up[i].δ_nondim[k] = 0.0
                aux_up[i].entr_rate_inv_s[k] = 0.0
                aux_up[i].detr_rate_inv_s[k] = 0.0
            end
        end
    end
end

##### Compute machine learning entr detr
function compute_ml_entr_detr!(
    state::State,
    grid::Grid,
    edmf::EDMFModel,
    param_set::APS,
    surf::SurfaceBase,
    Δt::Real,
    εδ_closure::EntrNone,
)
    return nothing
end

function compute_ml_entr_detr!(
    state::State,
    grid::Grid,
    edmf::EDMFModel,
    param_set::APS,
    surf::SurfaceBase,
    Δt::Real,
    εδ_closure::AbstractMLEntrDetrModel,
)
    FT = float_type(state)
    N_up = n_updrafts(edmf)
    aux_up = center_aux_updrafts(state)
    prog_up = center_prog_updrafts(state)
    aux_up_f = face_aux_updrafts(state)
    aux_en = center_aux_environment(state)
    aux_en_f = face_aux_environment(state)
    prog_gm_f = face_prog_grid_mean(state)
    prog_gm = center_prog_grid_mean(state)
    aux_gm = center_aux_grid_mean(state)
    aux_tc = center_aux_turbconv(state)
    p_c = aux_gm.p
    ρ_c = prog_gm.ρ
    g::FT = TCP.grav(param_set)
    w_up_c = aux_tc.w_up_c
    w_en_c = aux_tc.w_en_c
    wvec = CC.Geometry.WVector
    max_area = edmf.max_area
    plume_scale_height = map(1:N_up) do i
        compute_plume_scale_height(grid, state, edmf.H_up_min, i)
    end
    Ic = CCO.InterpolateF2C()
    ∇c = CCO.DivergenceF2C()
    LB = CCO.LeftBiasedC2F(; bottom = CCO.SetValue(FT(0)))
    @inbounds for i in 1:N_up
        # compute ∇m at cell centers
        a_up = aux_up[i].area
        w_up = aux_up_f[i].w
        Π_groups = aux_up[i].Π_groups
        w_en = aux_en_f.w
        w_gm = prog_gm_f.w
        @. w_up_c = Ic(w_up)
        @. w_en_c = Ic(w_en)
        @inbounds for k in real_center_indices(grid)
            # entrainment

            q_cond_up = TD.condensate(TD.PhasePartition(aux_up[i].q_tot[k], aux_up[i].q_liq[k], aux_up[i].q_ice[k]))
            q_cond_en = TD.condensate(TD.PhasePartition(aux_en.q_tot[k], aux_en.q_liq[k], aux_en.q_ice[k]))
            if aux_up[i].area[k] > edmf.minimum_area
                εδ_model_vars = (;
                    q_cond_up = q_cond_up, # updraft condensate (liquid water + ice)
                    q_cond_en = q_cond_en, # environment condensate (liquid water + ice)
                    w_up = w_up_c[k], # updraft vertical velocity
                    w_en = w_en_c[k], # environment vertical velocity
                    b_up = aux_up[i].buoy[k], # updraft buoyancy
                    b_en = aux_en.buoy[k], # environment buoyancy
                    tke_gm = aux_gm.tke[k], # grid mean tke
                    tke_en = aux_en.tke[k], # environment tke
                    a_up = aux_up[i].area[k], # updraft area fraction
                    a_en = aux_en.area[k], # environment area fraction
                    H_up = plume_scale_height[i], # plume scale height
                    ref_H = p_c[k] / (ρ_c[k] * g), # reference state scale height
                    RH_up = aux_up[i].RH[k], # updraft relative humidity
                    RH_en = aux_en.RH[k], # environment relative humidity
                    max_area = max_area, # maximum updraft area
                    zc_i = FT(grid.zc[k].z), # vertical coordinate
                    ∂lnM∂z = aux_tc.∂lnM∂z[k], # ln(massflux) gradient
                    ∂M∂z = aux_tc.∂M∂z[k],
                    entr_Π_subset = entrainment_Π_subset(edmf), # indices of Pi groups to include
                    ∂w∂z = aux_tc.∂w∂z[k],
                    ∂M∂z_ρa = aux_tc.∂M∂z_ρa[k],
                )
                # store pi groups for output
                Π = non_dimensional_groups(εδ_closure, εδ_model_vars)
                @assert length(Π) == n_Π_groups(edmf)
                for Π_i in 1:length(entrainment_Π_subset(edmf))
                    Π_groups[Π_i][k] = Π[Π_i]
                end
                # update fractional and turbulent entr/detr
                # fractional, turbulent & nondimensional entrainment
                ε_ml_nondim, δ_ml_nondim = non_dimensional_function(εδ_closure, εδ_model_vars)

                ε_dyn, δ_dyn = εδ_dyn(
                    εδ_closure,
                    εδ_model_vars,
                    edmf.entr_dim_scale,
                    edmf.detr_dim_scale,
                    ε_ml_nondim,
                    δ_ml_nondim,
                )

                if edmf.entrainment_type isa FractionalEntrModel

                    aux_up[i].entr_ml[k] = ε_dyn
                    aux_up[i].detr_ml[k] = δ_dyn
                    # update nondimensional entr/detr
                    aux_up[i].ε_ml_nondim[k] = ε_ml_nondim
                    aux_up[i].δ_ml_nondim[k] = δ_ml_nondim

                    aux_up[i].entr_rate_inv_s[k] = w_up_c[k] * ε_dyn
                    aux_up[i].detr_rate_inv_s[k] = w_up_c[k] * δ_dyn

                elseif edmf.entrainment_type isa TotalRateEntrModel
                    FT = eltype(εδ_model_vars.q_cond_up)
                    aux_up[i].entr_ml[k] = ε_dyn / (w_up_c[k] + eps(FT)) # fractional rates
                    aux_up[i].detr_ml[k] = δ_dyn / (w_up_c[k] + eps(FT)) # fractional rates
                    # update nondimensional entr/detr
                    aux_up[i].ε_ml_nondim[k] = ε_ml_nondim
                    aux_up[i].δ_ml_nondim[k] = δ_ml_nondim

                    aux_up[i].entr_rate_inv_s[k] = ε_dyn
                    aux_up[i].detr_rate_inv_s[k] = δ_dyn
                end

            else
                aux_up[i].entr_ml[k] = 0.0
                aux_up[i].detr_ml[k] = 0.0
                aux_up[i].ε_ml_nondim[k] = 0.0
                aux_up[i].δ_ml_nondim[k] = 0.0
                aux_up[i].entr_rate_inv_s[k] = 0.0
                aux_up[i].detr_rate_inv_s[k] = 0.0
            end

        end
    end
end

##### Compute nonlocal machine learning entr detr
function compute_ml_entr_detr!(
    state::State,
    grid::Grid,
    edmf::EDMFModel,
    param_set::APS,
    surf::SurfaceBase,
    Δt::Real,
    εδ_model::AbstractMLNonLocalEntrDetrModel,
)
    FT = float_type(state)
    N_up = n_updrafts(edmf)
    aux_up = center_aux_updrafts(state)
    aux_up_f = face_aux_updrafts(state)
    aux_en = center_aux_environment(state)
    aux_en_f = face_aux_environment(state)
    prog_gm_f = face_prog_grid_mean(state)
    aux_gm = center_aux_grid_mean(state)
    aux_tc = center_aux_turbconv(state)
    prog_gm = center_prog_grid_mean(state)
    p_c = aux_gm.p
    ρ_c = prog_gm.ρ
    g::FT = TCP.grav(param_set)
    w_up_c = aux_tc.w_up_c
    w_en_c = aux_tc.w_en_c
    wvec = CC.Geometry.WVector
    max_area = edmf.max_area
    plume_scale_height = map(1:N_up) do i
        compute_plume_scale_height(grid, state, edmf.H_up_min, i)
    end

    Ic = CCO.InterpolateF2C()
    ∇c = CCO.DivergenceF2C()
    LB = CCO.LeftBiasedC2F(; bottom = CCO.SetValue(FT(0)))
    @inbounds for i in 1:N_up
        # compute ∇m at cell centers
        a_up = aux_up[i].area
        w_up = aux_up_f[i].w
        Π_groups = aux_up[i].Π_groups
        w_en = aux_en_f.w
        w_gm = prog_gm_f.w
        @. w_up_c = Ic(w_up)
        @. w_en_c = Ic(w_en)

        @inbounds for k in real_center_indices(grid)
            # entrainment

            q_cond_up = TD.condensate(TD.PhasePartition(aux_up[i].q_tot[k], aux_up[i].q_liq[k], aux_up[i].q_ice[k]))
            q_cond_en = TD.condensate(TD.PhasePartition(aux_en.q_tot[k], aux_en.q_liq[k], aux_en.q_ice[k]))

            if aux_up[i].area[k] > edmf.minimum_area
                εδ_model_vars = (;
                    q_cond_up = q_cond_up, # updraft condensate (liquid water + ice)
                    q_cond_en = q_cond_en, # environment condensate (liquid water + ice)
                    w_up = w_up_c[k], # updraft vertical velocity
                    w_en = w_en_c[k], # environment vertical velocity
                    b_up = aux_up[i].buoy[k], # updraft buoyancy
                    b_en = aux_en.buoy[k], # environment buoyancy
                    tke_gm = aux_gm.tke[k], # grid mean tke
                    tke_en = aux_en.tke[k], # environment tke
                    a_up = aux_up[i].area[k], # updraft area fraction
                    a_en = aux_en.area[k], # environment area fraction
                    H_up = plume_scale_height[i], # plume scale height
                    ref_H = p_c[k] / (ρ_c[k] * g), # reference state scale height
                    RH_up = aux_up[i].RH[k], # updraft relative humidity
                    RH_en = aux_en.RH[k], # environment relative humidity
                    max_area = max_area, # maximum updraft area
                    zc_i = FT(grid.zc[k].z), # vertical coordinate
                    ∂lnM∂z = aux_tc.∂lnM∂z[k], # ln(massflux) gradient
                    ε_ml_nondim = aux_up[i].ε_ml_nondim[k], # nondimensional fractional dynamical entrainment
                    δ_ml_nondim = aux_up[i].δ_ml_nondim[k], # nondimensional fractional dynamical detrainment
                    ∂M∂z = aux_tc.∂M∂z[k],
                    entr_Π_subset = entrainment_Π_subset(edmf), # indices of Pi groups to include
                    ∂w∂z = aux_tc.∂w∂z[k],
                    ∂M∂z_ρa = aux_tc.∂M∂z_ρa[k],
                )
                Π = non_dimensional_groups(εδ_model, εδ_model_vars)
                @assert length(Π) == n_Π_groups(edmf)
                for Π_i in 1:length(entrainment_Π_subset(edmf))
                    Π_groups[Π_i][k] = Π[Π_i]
                end

            else
                for Π_i in 1:length(entrainment_Π_subset(edmf))
                    aux_up[i].Π_groups[Π_i][k] = 0.0
                end
            end
        end

        Π_groups = parent(aux_up[i].Π_groups)
        ε_ml_nondim = parent(aux_up[i].ε_ml_nondim)
        δ_ml_nondim = parent(aux_up[i].δ_ml_nondim)
        non_dimensional_function!(ε_ml_nondim, δ_ml_nondim, Π_groups, εδ_model)

        @inbounds for k in real_center_indices(grid)
            ε_dim_scale = entrainment_dim_scale(
                εδ_model,
                aux_up[i].buoy[k],
                aux_en.buoy[k],
                w_up_c[k],
                w_en_c[k],
                aux_en.tke[k],
                FT(grid.zc[k].z),
                p_c[k] / (ρ_c[k] * g),
                aux_tc.∂lnM∂z[k],
                aux_tc.∂M∂z[k],
                aux_tc.∂w∂z[k],
                aux_tc.∂M∂z_ρa[k],
                edmf.entr_dim_scale,
            )
            δ_dim_scale = entrainment_dim_scale(
                εδ_model,
                aux_up[i].buoy[k],
                aux_en.buoy[k],
                w_up_c[k],
                w_en_c[k],
                aux_en.tke[k],
                FT(grid.zc[k].z),
                p_c[k] / (ρ_c[k] * g),
                aux_tc.∂lnM∂z[k],
                aux_tc.∂M∂z[k],
                aux_tc.∂w∂z[k],
                aux_tc.∂M∂z_ρa[k],
                edmf.detr_dim_scale,
            )

            area_limiter = max_area_limiter(εδ_model, max_area, aux_up[i].area[k])

            aux_up[i].entr_ml[k] = ε_dim_scale * aux_up[i].ε_ml_nondim[k]
            aux_up[i].detr_ml[k] = δ_dim_scale * (aux_up[i].δ_ml_nondim[k] + area_limiter)
        end

        @. aux_up[i].ε_ml_nondim = ifelse(aux_up[i].area > edmf.minimum_area, aux_up[i].ε_ml_nondim, 0)
        @. aux_up[i].δ_ml_nondim = ifelse(aux_up[i].area > edmf.minimum_area, aux_up[i].δ_ml_nondim, 0)
        @. aux_up[i].entr_ml = ifelse(aux_up[i].area > edmf.minimum_area, aux_up[i].entr_ml, 0)
        @. aux_up[i].detr_ml = ifelse(aux_up[i].area > edmf.minimum_area, aux_up[i].detr_ml, 0)

    end
end
