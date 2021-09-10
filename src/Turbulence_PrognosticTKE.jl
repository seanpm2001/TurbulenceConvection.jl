
function initialize(
    self::EDMF_PrognosticTKE,
    Case::CasesBase,
    GMV::GridMeanVariables,
    Ref::ReferenceState,
    TS::TimeStepping,
)
    if Case.casename == "DryBubble"
        initialize_DryBubble(self, self.UpdVar, GMV, Ref)
    else
        initialize(self, self.UpdVar, GMV)
    end
    decompose_environment(self, GMV)
    saturation_adjustment(self.EnvThermo, self.EnvVar)
    buoyancy(self.UpdThermo, self.UpdVar, self.EnvVar, GMV, self.extrapolate_buoyancy)
    update_inversion(self, GMV, Case.inversion_option)
    self.wstar = get_wstar(Case.Sur.bflux, self.zi)
    microphysics(self.EnvThermo, self.EnvVar, self.Rain, TS.dt)
    initialize_covariance(self, GMV, Case)
    return
end

# Initialize the IO pertaining to this class
function initialize_io(self::EDMF_PrognosticTKE, Stats::NetCDFIO_Stats)

    initialize_io(self.UpdVar, Stats)
    initialize_io(self.EnvVar, Stats)
    initialize_io(self.Rain, Stats)

    add_profile(Stats, "eddy_viscosity")
    add_profile(Stats, "eddy_diffusivity")
    add_profile(Stats, "entrainment_sc")
    add_profile(Stats, "detrainment_sc")
    add_profile(Stats, "nh_pressure")
    add_profile(Stats, "nh_pressure_adv")
    add_profile(Stats, "nh_pressure_drag")
    add_profile(Stats, "nh_pressure_b")
    add_profile(Stats, "asp_ratio")
    add_profile(Stats, "horiz_K_eddy")
    add_profile(Stats, "sorting_function")
    add_profile(Stats, "b_mix")
    add_ts(Stats, "rd")
    add_profile(Stats, "turbulent_entrainment")
    add_profile(Stats, "turbulent_entrainment_full")
    add_profile(Stats, "turbulent_entrainment_W")
    add_profile(Stats, "turbulent_entrainment_H")
    add_profile(Stats, "turbulent_entrainment_QT")
    add_profile(Stats, "massflux")
    add_profile(Stats, "massflux_h")
    add_profile(Stats, "massflux_qt")
    add_profile(Stats, "massflux_tendency_h")
    add_profile(Stats, "massflux_tendency_qt")
    add_profile(Stats, "diffusive_flux_h")
    add_profile(Stats, "diffusive_flux_u")
    add_profile(Stats, "diffusive_flux_v")
    add_profile(Stats, "diffusive_flux_qt")
    add_profile(Stats, "diffusive_tendency_h")
    add_profile(Stats, "diffusive_tendency_qt")
    add_profile(Stats, "total_flux_h")
    add_profile(Stats, "total_flux_qt")
    add_profile(Stats, "mixing_length")
    add_profile(Stats, "updraft_qt_precip")
    add_profile(Stats, "updraft_thetal_precip")
    # Diff mixing lengths: Ignacio
    add_profile(Stats, "ed_length_scheme")
    add_profile(Stats, "mixing_length_ratio")
    add_profile(Stats, "entdet_balance_length")
    add_profile(Stats, "interdomain_tke_t")
    add_profile(Stats, "tke_buoy")
    add_profile(Stats, "tke_dissipation")
    add_profile(Stats, "tke_entr_gain")
    add_profile(Stats, "tke_detr_loss")
    add_profile(Stats, "tke_shear")
    add_profile(Stats, "tke_pressure")
    add_profile(Stats, "tke_interdomain")
    add_profile(Stats, "Hvar_dissipation")
    add_profile(Stats, "QTvar_dissipation")
    add_profile(Stats, "HQTcov_dissipation")
    add_profile(Stats, "Hvar_entr_gain")
    add_profile(Stats, "QTvar_entr_gain")
    add_profile(Stats, "Hvar_detr_loss")
    add_profile(Stats, "QTvar_detr_loss")
    add_profile(Stats, "HQTcov_detr_loss")
    add_profile(Stats, "HQTcov_entr_gain")
    add_profile(Stats, "Hvar_shear")
    add_profile(Stats, "QTvar_shear")
    add_profile(Stats, "HQTcov_shear")
    add_profile(Stats, "Hvar_rain")
    add_profile(Stats, "QTvar_rain")
    add_profile(Stats, "HQTcov_rain")
    add_profile(Stats, "Hvar_interdomain")
    add_profile(Stats, "QTvar_interdomain")
    add_profile(Stats, "HQTcov_interdomain")
    return
end

function io(self::EDMF_PrognosticTKE, Stats::NetCDFIO_Stats, TS::TimeStepping)

    grid = get_grid(self)
    ref_state = reference_state(self)
    cinterior = grid.cinterior
    finterior = grid.finterior

    mean_nh_pressure = face_field(grid)
    mean_nh_pressure_adv = face_field(grid)
    mean_nh_pressure_drag = face_field(grid)
    mean_nh_pressure_b = face_field(grid)

    mean_asp_ratio = center_field(grid)
    mean_entr_sc = center_field(grid)
    mean_detr_sc = center_field(grid)
    massflux = center_field(grid)
    mf_h = center_field(grid)
    mf_qt = center_field(grid)
    mean_frac_turb_entr = center_field(grid)
    mean_horiz_K_eddy = center_field(grid)
    mean_sorting_function = center_field(grid)
    mean_b_mix = center_field(grid)

    io(self.UpdVar, Stats, ref_state)
    io(self.EnvVar, Stats, ref_state)
    io(self.Rain, Stats, ref_state, self.UpdThermo, self.EnvThermo, TS)

    a_up_bulk = self.UpdVar.Area.bulkvalues
    a_up = self.UpdVar.Area.values

    write_profile(Stats, "eddy_viscosity", diffusivity_m(self).values[cinterior])
    write_profile(Stats, "eddy_diffusivity", diffusivity_h(self).values[cinterior])
    write_ts(Stats, "rd", mean(self.pressure_plume_spacing))

    @inbounds for k in real_center_indices(grid)
        mf_h[k] = interpf2c(self.massflux_h, grid, k)
        mf_qt[k] = interpf2c(self.massflux_qt, grid, k)
        if self.UpdVar.Area.bulkvalues[k] > 0.0
            @inbounds for i in xrange(self.n_updrafts)
                massflux[k] += interpf2c(self.m, grid, k, i)
                mean_entr_sc[k] += a_up[i, k] * self.entr_sc[i, k] / a_up_bulk[k]
                mean_detr_sc[k] += a_up[i, k] * self.detr_sc[i, k] / a_up_bulk[k]
                mean_asp_ratio[k] += a_up[i, k] * self.asp_ratio[i, k] / a_up_bulk[k]
                mean_frac_turb_entr[k] += a_up[i, k] * self.frac_turb_entr[i, k] / a_up_bulk[k]
                mean_horiz_K_eddy[k] += a_up[i, k] * self.horiz_K_eddy[i, k] / a_up_bulk[k]
                mean_sorting_function[k] += a_up[i, k] * self.sorting_function[i, k] / a_up_bulk[k]
                mean_b_mix[k] += a_up[i, k] * self.b_mix[i, k] / a_up_bulk[k]
            end
        end
    end

    @inbounds for k in real_face_indices(grid)
        a_up_bulk_f =
            interpc2f(a_up_bulk, grid, k; bottom = SetValue(sum(self.area_surface_bc)), top = SetZeroGradient())
        if a_up_bulk_f > 0.0
            @inbounds for i in xrange(self.n_updrafts)
                a_up_f =
                    interpc2f(a_up, grid, k, i; bottom = SetValue(self.area_surface_bc[i]), top = SetZeroGradient())
                mean_nh_pressure[k] += a_up_f * self.nh_pressure[i, k] / a_up_bulk_f
                mean_nh_pressure_b[k] += a_up_f * self.nh_pressure_b[i, k] / a_up_bulk_f
                mean_nh_pressure_adv[k] += a_up_f * self.nh_pressure_adv[i, k] / a_up_bulk_f
                mean_nh_pressure_drag[k] += a_up_f * self.nh_pressure_drag[i, k] / a_up_bulk_f
            end
        end
    end

    write_profile(Stats, "turbulent_entrainment", mean_frac_turb_entr[cinterior])
    write_profile(Stats, "horiz_K_eddy", mean_horiz_K_eddy[cinterior])
    write_profile(Stats, "entrainment_sc", mean_entr_sc[cinterior])
    write_profile(Stats, "detrainment_sc", mean_detr_sc[cinterior])
    write_profile(Stats, "nh_pressure", mean_nh_pressure[finterior])
    write_profile(Stats, "nh_pressure_adv", mean_nh_pressure_adv[finterior])
    write_profile(Stats, "nh_pressure_drag", mean_nh_pressure_drag[finterior])
    write_profile(Stats, "nh_pressure_b", mean_nh_pressure_b[finterior])
    write_profile(Stats, "asp_ratio", mean_asp_ratio[cinterior])
    write_profile(Stats, "massflux", massflux[cinterior])
    write_profile(Stats, "massflux_h", mf_h[cinterior])
    write_profile(Stats, "massflux_qt", mf_qt[cinterior])
    write_profile(Stats, "massflux_tendency_h", self.massflux_tendency_h[cinterior])
    write_profile(Stats, "massflux_tendency_qt", self.massflux_tendency_qt[cinterior])
    write_profile(Stats, "diffusive_flux_h", self.diffusive_flux_h[cinterior])
    write_profile(Stats, "diffusive_flux_qt", self.diffusive_flux_qt[cinterior])
    write_profile(Stats, "diffusive_flux_u", self.diffusive_flux_u[cinterior])
    write_profile(Stats, "diffusive_flux_v", self.diffusive_flux_v[cinterior])
    write_profile(Stats, "diffusive_tendency_h", self.diffusive_tendency_h[cinterior])
    write_profile(Stats, "diffusive_tendency_qt", self.diffusive_tendency_qt[cinterior])
    write_profile(Stats, "total_flux_h", mf_h[cinterior] .+ self.diffusive_flux_h[cinterior])
    write_profile(Stats, "total_flux_qt", mf_qt[cinterior] .+ self.diffusive_flux_qt[cinterior])
    write_profile(Stats, "mixing_length", self.mixing_length[cinterior])
    write_profile(Stats, "updraft_qt_precip", self.UpdThermo.prec_source_qt_tot[cinterior])
    write_profile(Stats, "updraft_thetal_precip", self.UpdThermo.prec_source_h_tot[cinterior])

    #Different mixing lengths : Ignacio
    write_profile(Stats, "ed_length_scheme", self.mls[cinterior])
    write_profile(Stats, "mixing_length_ratio", self.ml_ratio[cinterior])
    write_profile(Stats, "entdet_balance_length", self.l_entdet[cinterior])
    write_profile(Stats, "interdomain_tke_t", self.b[cinterior])
    compute_covariance_dissipation(self, self.EnvVar.TKE)
    write_profile(Stats, "tke_dissipation", self.EnvVar.TKE.dissipation[cinterior])
    write_profile(Stats, "tke_entr_gain", self.EnvVar.TKE.entr_gain[cinterior])
    compute_covariance_detr(self, self.EnvVar.TKE)
    write_profile(Stats, "tke_detr_loss", self.EnvVar.TKE.detr_loss[cinterior])
    write_profile(Stats, "tke_shear", self.EnvVar.TKE.shear[cinterior])
    write_profile(Stats, "tke_buoy", self.EnvVar.TKE.buoy[cinterior])
    write_profile(Stats, "tke_pressure", self.EnvVar.TKE.press[cinterior])
    write_profile(Stats, "tke_interdomain", self.EnvVar.TKE.interdomain[cinterior])

    compute_covariance_dissipation(self, self.EnvVar.Hvar)
    write_profile(Stats, "Hvar_dissipation", self.EnvVar.Hvar.dissipation[cinterior])
    compute_covariance_dissipation(self, self.EnvVar.QTvar)
    write_profile(Stats, "QTvar_dissipation", self.EnvVar.QTvar.dissipation[cinterior])
    compute_covariance_dissipation(self, self.EnvVar.HQTcov)
    write_profile(Stats, "HQTcov_dissipation", self.EnvVar.HQTcov.dissipation[cinterior])
    write_profile(Stats, "Hvar_entr_gain", self.EnvVar.Hvar.entr_gain[cinterior])
    write_profile(Stats, "QTvar_entr_gain", self.EnvVar.QTvar.entr_gain[cinterior])
    write_profile(Stats, "HQTcov_entr_gain", self.EnvVar.HQTcov.entr_gain[cinterior])
    compute_covariance_detr(self, self.EnvVar.Hvar)
    compute_covariance_detr(self, self.EnvVar.QTvar)
    compute_covariance_detr(self, self.EnvVar.HQTcov)
    write_profile(Stats, "Hvar_detr_loss", self.EnvVar.Hvar.detr_loss[cinterior])
    write_profile(Stats, "QTvar_detr_loss", self.EnvVar.QTvar.detr_loss[cinterior])
    write_profile(Stats, "HQTcov_detr_loss", self.EnvVar.HQTcov.detr_loss[cinterior])
    write_profile(Stats, "Hvar_shear", self.EnvVar.Hvar.shear[cinterior])
    write_profile(Stats, "QTvar_shear", self.EnvVar.QTvar.shear[cinterior])
    write_profile(Stats, "HQTcov_shear", self.EnvVar.HQTcov.shear[cinterior])
    write_profile(Stats, "Hvar_rain", self.EnvVar.Hvar.rain_src[cinterior])
    write_profile(Stats, "QTvar_rain", self.EnvVar.QTvar.rain_src[cinterior])
    write_profile(Stats, "HQTcov_rain", self.EnvVar.HQTcov.rain_src[cinterior])
    write_profile(Stats, "Hvar_interdomain", self.EnvVar.Hvar.interdomain[cinterior])
    write_profile(Stats, "QTvar_interdomain", self.EnvVar.QTvar.interdomain[cinterior])
    write_profile(Stats, "HQTcov_interdomain", self.EnvVar.HQTcov.interdomain[cinterior])
    return
end

update_surface(Case::CasesBase, GMV::GridMeanVariables, TS::TimeStepping) =
    error("update_surface should be overloaded in case-specific methods (in Cases.jl)")
update_forcing(Case::CasesBase, GMV::GridMeanVariables, TS::TimeStepping) =
    error("update_forcing should be overloaded in case-specific methods (in Cases.jl)")
update_radiation(Case::CasesBase, GMV::GridMeanVariables, TS::TimeStepping) =
    error("update_radiation should be overloaded in case-specific methods (in Cases.jl)")

function update_cloud_frac(self::EDMF_PrognosticTKE, GMV::GridMeanVariables)
    grid = get_grid(self)
    # update grid-mean cloud fraction and cloud cover
    @inbounds for k in real_center_indices(grid) # update grid-mean cloud fraction and cloud cover
        self.EnvVar.Area.values[k] = 1 - self.UpdVar.Area.bulkvalues[k]
        GMV.cloud_fraction.values[k] =
            self.EnvVar.Area.values[k] * self.EnvVar.cloud_fraction.values[k] +
            self.UpdVar.Area.bulkvalues[k] * self.UpdVar.cloud_fraction[k]
    end
    GMV.cloud_cover = min(self.EnvVar.cloud_cover + sum(self.UpdVar.cloud_cover), 1)
end

function compute_gm_tendencies!(grid, Case, GMV, Ref, TS)
    param_set = parameter_set(GMV)
    GMV.U.tendencies .= 0
    GMV.V.tendencies .= 0
    GMV.QT.tendencies .= 0
    GMV.H.tendencies .= 0

    @inbounds for k in real_center_indices(grid)
        # Apply large-scale horizontal advection tendencies
        ts = TD.PhaseEquil_pθq(param_set, Ref.p0_half[k], GMV.H.values[k], GMV.QT.values[k])
        Π = TD.exner(ts)

        if Case.Fo.apply_coriolis
            GMV.U.tendencies[k] -= Case.Fo.coriolis_param * (Case.Fo.vg[k] - GMV.V.values[k])
            GMV.V.tendencies[k] += Case.Fo.coriolis_param * (Case.Fo.ug[k] - GMV.U.values[k])
        end
        if rad_type(Case.Rad) <: Union{RadiationDYCOMS_RF01, RadiationLES}
            GMV.H.tendencies[k] += Case.Rad.dTdt[k] / Π
        end
        H_cut = ccut_downwind(GMV.H.values, grid, k)
        q_tot_cut = ccut_downwind(GMV.QT.values, grid, k)
        ∇H = c∇_downwind(H_cut, grid, k; bottom = FreeBoundary(), top = SetGradient(0))
        ∇q_tot = c∇_downwind(q_tot_cut, grid, k; bottom = FreeBoundary(), top = SetGradient(0))

        if force_type(Case.Fo) <: ForcingDYCOMS_RF01
            GMV.QT.tendencies[k] += Case.Fo.dqtdt[k]
            # Apply large-scale subsidence tendencies
            GMV.H.tendencies[k] -= ∇H * Case.Fo.subsidence[k]
            GMV.QT.tendencies[k] -= ∇q_tot * Case.Fo.subsidence[k]
        end

        if force_type(Case.Fo) <: ForcingStandard
            if Case.Fo.apply_subsidence
                GMV.H.tendencies[k] -= ∇H * Case.Fo.subsidence[k]
                GMV.QT.tendencies[k] -= ∇q_tot * Case.Fo.subsidence[k]
            end
            GMV.H.tendencies[k] += Case.Fo.dTdt[k] / Π
            GMV.QT.tendencies[k] += Case.Fo.dqtdt[k]
        end

        if force_type(Case.Fo) <: ForcingLES
            H_horz_adv = Case.Fo.dtdt_hadv[k] / Π
            H_nudge = Case.Fo.dtdt_nudge[k] / Π
            H_fluc = Case.Fo.dtdt_fluc[k] / Π

            GMV_U_nudge_k = (Case.Fo.u_nudge[k] - GMV.U.values[k]) / Case.Fo.nudge_tau
            GMV_V_nudge_k = (Case.Fo.v_nudge[k] - GMV.V.values[k]) / Case.Fo.nudge_tau
            if Case.Fo.apply_subsidence
                # Apply large-scale subsidence tendencies
                GMV_H_subsidence_k = -∇H * Case.Fo.subsidence[k]
                GMV_QT_subsidence_k = -∇q_tot * Case.Fo.subsidence[k]
            else
                GMV_H_subsidence_k = 0.0
                GMV_QT_subsidence_k = 0.0
            end

            GMV.H.tendencies[k] += H_horz_adv + H_nudge + H_fluc + GMV_H_subsidence_k
            GMV.QT.tendencies[k] +=
                Case.Fo.dqtdt_hadv[k] + Case.Fo.dqtdt_nudge[k] + GMV_QT_subsidence_k + Case.Fo.dqtdt_fluc[k]

            GMV.U.tendencies[k] += GMV_U_nudge_k
            GMV.V.tendencies[k] += GMV_V_nudge_k
        end

    end
end

# Perform the update of the scheme
function update(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase, TS::TimeStepping)

    grid = get_grid(self)
    ref_state = reference_state(self)
    param_set = parameter_set(self)

    # Update aux / pre-tendencies filters. TODO: combine these into a function that minimizes traversals
    # Some of these methods should probably live in `compute_tendencies`, when written, but we'll
    # treat them as auxiliary variables for now, until we disentangle the tendency computations.
    update_surface(Case, GMV, TS)
    update_forcing(Case, GMV, TS)
    update_radiation(Case, GMV, TS)
    update_GMV_diagnostics(self, GMV)
    compute_pressure_plume_spacing(self, GMV, Case)
    compute_updraft_closures(self, GMV, Case)
    compute_eddy_diffusivities_tke(self, GMV, Case)
    compute_GMV_MF(self, GMV, TS)
    compute_covariance_rhs(self, GMV, Case, TS)

    # compute tendencies
    compute_gm_tendencies!(grid, Case, GMV, self.Ref, TS)

    clear_precip_sources(self.UpdThermo)

    set_old_with_values(self.UpdVar)
    set_updraft_surface_bc(self, GMV, Case)

    # update
    solve_updraft(self, GMV, TS)
    @inbounds for k in real_center_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)
            # saturation adjustment
            sa = eos(param_set, ref_state.p0_half[k], self.UpdVar.QT.new[i, k], self.UpdVar.H.new[i, k])
            self.UpdVar.QL.values[i, k] = sa.ql
            self.UpdVar.T.values[i, k] = sa.T
        end
    end
    update_GMV_ED(self, GMV, Case, TS)
    update_covariance(self, GMV, Case, TS)
    update_GMV_turbulence(self, GMV, Case, TS)

    # update microphysics
    microphysics(self.UpdThermo, self.UpdVar, self.Rain, TS.dt) # causes division error in dry bubble first time step
    microphysics(self.EnvThermo, self.EnvVar, self.Rain, TS.dt) # saturation adjustment + rain creation
    update_total_precip_sources(self.UpdThermo)

    if self.Rain.rain_model == "clima_1m"
        # sum updraft and environment rain into bulk rain
        sum_subdomains_rain(self.Rain, self.UpdThermo, self.EnvThermo)

        # rain fall (all three categories are assumed to be falling though "grid-mean" conditions
        solve_rain_fall(self.rainphysics, self.Rain, GMV, TS, self.Rain.QR, self.Rain.RainArea)
        solve_rain_fall(self.rainphysics, self.Rain, GMV, TS, self.Rain.Upd_QR, self.Rain.Upd_RainArea)
        solve_rain_fall(self.rainphysics, self.Rain, GMV, TS, self.Rain.Env_QR, self.Rain.Env_RainArea)

        # rain evaporation (all three categories are assumed to be evaporating in "grid-mean" conditions
        solve_rain_evap(self.rainphysics, self.Rain, GMV, TS, self.Rain.QR, self.Rain.RainArea)
        solve_rain_evap(self.rainphysics, self.Rain, GMV, TS, self.Rain.Upd_QR, self.Rain.Upd_RainArea)
        solve_rain_evap(self.rainphysics, self.Rain, GMV, TS, self.Rain.Env_QR, self.Rain.Env_RainArea)
    end
    update_cloud_frac(self, GMV)

    # set values
    set_values_with_new(self.UpdVar)
    zero_area_fraction_cleanup(self, GMV)
    decompose_environment(self, GMV)
    saturation_adjustment(self.EnvThermo, self.EnvVar)
    buoyancy(self.UpdThermo, self.UpdVar, self.EnvVar, GMV, self.extrapolate_buoyancy)

    update(GMV, TS)
    return
end

function update_GMV_turbulence(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase, TS::TimeStepping)

    @inbounds for k in real_center_indices(self.Gr)
        GMV.H.tendencies[k] += (GMV.H.new[k] - GMV.H.values[k]) * TS.dti
        GMV.QT.tendencies[k] += (GMV.QT.new[k] - GMV.QT.values[k]) * TS.dti
        GMV.U.tendencies[k] += (GMV.U.new[k] - GMV.U.values[k]) * TS.dti
        GMV.V.tendencies[k] += (GMV.V.new[k] - GMV.V.values[k]) * TS.dti
    end

    return
end

function compute_eddy_diffusivities_tke(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase)
    grid = get_grid(self)
    param_set = parameter_set(GMV)
    g = CPP.grav(param_set)
    ref_state = reference_state(self)
    kc_surf = kc_surface(grid)
    ω_pr = CPEDMF.ω_pr(param_set)
    Pr_n = CPEDMF.Pr_n(param_set)
    c_m = CPEDMF.c_m(param_set)
    KM = diffusivity_m(self)
    KH = diffusivity_h(self)
    obukhov_length = Case.Sur.obukhov_length

    @inbounds for k in real_center_indices(grid)

        # compute shear
        U_cut = ccut(GMV.U.values, grid, k)
        V_cut = ccut(GMV.V.values, grid, k)
        wc_en = interpf2c(self.EnvVar.W.values, grid, k)
        wc_up = interpf2c.(Ref(self.UpdVar.W.values), Ref(grid), k, 1:(self.n_updrafts))
        w_dual = dual_faces(self.EnvVar.W.values, grid, k)

        ∇U = c∇(U_cut, grid, k; bottom = SetGradient(0), top = SetGradient(0))
        ∇V = c∇(V_cut, grid, k; bottom = SetGradient(0), top = SetGradient(0))
        ∇w = ∇f2c(w_dual, grid, k; bottom = SetGradient(0), top = SetGradient(0))
        Shear² = ∇U^2 + ∇V^2 + ∇w^2

        QT_cut = ccut(self.EnvVar.QT.values, grid, k)
        ∂qt∂z = c∇(QT_cut, grid, k; bottom = SetGradient(0), top = SetGradient(0))
        THL_cut = ccut(self.EnvVar.H.values, grid, k)
        ∂θl∂z = c∇(THL_cut, grid, k; bottom = SetGradient(0), top = SetGradient(0))
        # buoyancy_gradients
        bg_model = Tan2018(;
            qt_dry = self.EnvThermo.qt_dry[k],
            th_dry = self.EnvThermo.th_dry[k],
            t_cloudy = self.EnvThermo.t_cloudy[k],
            qv_cloudy = self.EnvThermo.qv_cloudy[k],
            qt_cloudy = self.EnvThermo.qt_cloudy[k],
            th_cloudy = self.EnvThermo.th_cloudy[k],
            ∂qt∂z = ∂qt∂z,
            ∂θl∂z = ∂θl∂z,
            p0 = ref_state.p0_half[k],
            en_cld_frac = self.EnvVar.cloud_fraction.values[k],
            alpha0 = ref_state.alpha0_half[k],
        )
        bg = buoyancy_gradients(param_set, bg_model)

        # Limiting stratification scale (Deardorff, 1976)
        p0_cut = ccut(ref_state.p0_half, grid, k)
        T_cut = ccut(self.EnvVar.T.values, grid, k)
        QT_cut = ccut(self.EnvVar.QT.values, grid, k)
        QL_cut = ccut(self.EnvVar.QL.values, grid, k)
        ts_cut = TD.PhaseEquil_pTq.(param_set, p0_cut, T_cut, QT_cut)
        thv_cut = TD.virtual_pottemp.(ts_cut)

        ts = TD.PhaseEquil_pθq(param_set, ref_state.p0_half[k], self.EnvVar.H.values[k], self.EnvVar.QT.values[k])
        θv = TD.virtual_pottemp(ts)
        ∂θv∂z = c∇(thv_cut, grid, k; bottom = SetGradient(0), top = Extrapolate())
        # compute ∇Ri and Pr
        ∇_Ri = gradient_Richardson_number(bg.∂b∂z_θl, bg.∂b∂z_qt, Shear², eps(0.0))
        self.prandtl_nvec[k] = turbulent_Prandtl_number(obukhov_length, ∇_Ri, Pr_n, ω_pr)

        ml_model = MinDisspLen(;
            z = grid.z_half[k],
            obukhov_length = obukhov_length,
            κ_vk = vkb,
            tke_surf = self.EnvVar.TKE.values[kc_surf],
            ustar = Case.Sur.ustar,
            Pr = self.prandtl_nvec[k],
            p0 = ref_state.p0_half[k],
            ∂b∂z_θl = bg.∂b∂z_θl,
            Shear² = Shear²,
            ∂b∂z_qt = bg.∂b∂z_qt,
            ∂θv∂z = ∂θv∂z,
            ∂qt∂z = ∂qt∂z,
            ∂θl∂z = ∂θl∂z,
            θv = θv,
            tke = self.EnvVar.TKE.values[k],
            a_en = (1 - self.UpdVar.Area.bulkvalues[k]),
            wc_en = wc_en,
            wc_up = Tuple(wc_up),
            a_up = Tuple(self.UpdVar.Area.values[:, k]),
            ε_turb = Tuple(self.frac_turb_entr[:, k]),
            δ_dyn = Tuple(self.detr_sc[:, k]),
            en_cld_frac = self.EnvVar.cloud_fraction.values[k],
            θ_li_en = self.EnvVar.H.values[k],
            ql_en = self.EnvVar.QL.values[k],
            qt_en = self.EnvVar.QT.values[k],
            T_en = self.EnvVar.T.values[k],
            N_up = self.n_updrafts,
        )

        ml = mixing_length(param_set, ml_model)
        self.mls[k] = ml.min_len_ind
        self.mixing_length[k] = ml.mixing_length
        self.ml_ratio[k] = ml.ml_ratio

        KM.values[k] = c_m * self.mixing_length[k] * sqrt(max(self.EnvVar.TKE.values[k], 0.0))
        KH.values[k] = KM.values[k] / self.prandtl_nvec[k]

        self.EnvVar.TKE.buoy[k] = -ml_model.a_en * ref_state.rho0_half[k] * KH.values[k] * (bg.∂b∂z_θl + bg.∂b∂z_qt)
    end
    return
end

function set_updraft_surface_bc(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase)
    grid = get_grid(self)
    kc_surf = kc_surface(grid)
    update_inversion(self, GMV, Case.inversion_option)
    self.wstar = get_wstar(Case.Sur.bflux, self.zi)

    dzi = grid.dzi
    zLL = grid.z_half[kc_surf]
    ustar = Case.Sur.ustar
    oblength = Case.Sur.obukhov_length
    alpha0LL = reference_state(self).alpha0_half[kc_surf]
    qt_var = get_surface_variance(Case.Sur.rho_qtflux * alpha0LL, Case.Sur.rho_qtflux * alpha0LL, ustar, zLL, oblength)
    h_var = get_surface_variance(Case.Sur.rho_hflux * alpha0LL, Case.Sur.rho_hflux * alpha0LL, ustar, zLL, oblength)

    if Case.Sur.bflux > 0.0
        a_total = self.surface_area
        self.entr_surface_bc = 2.0 * dzi
        self.detr_surface_bc = 0.0
    else
        # a_total = self.surface_area
        a_total = self.minimum_area * 0.9
        self.entr_surface_bc = 0.0
        self.detr_surface_bc = 2.0 * dzi
    end

    a_ = a_total / self.n_updrafts
    @inbounds for i in xrange(self.n_updrafts)
        surface_scalar_coeff = percentile_bounds_mean_norm(1.0 - a_total + i * a_, 1.0 - a_total + (i + 1) * a_, 1000)
        self.area_surface_bc[i] = a_
        self.w_surface_bc[i] = 0.0
        self.h_surface_bc[i] = (GMV.H.values[kc_surf] + surface_scalar_coeff * sqrt(h_var))
        self.qt_surface_bc[i] = (GMV.QT.values[kc_surf] + surface_scalar_coeff * sqrt(qt_var))
    end
    return
end

function reset_surface_covariance(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase)
    flux1 = Case.Sur.rho_hflux
    flux2 = Case.Sur.rho_qtflux
    grid = get_grid(self)
    kc_surf = kc_surface(grid)
    ref_state = reference_state(self)
    zLL = grid.z_half[kc_surf]
    ustar = Case.Sur.ustar
    oblength = Case.Sur.obukhov_length
    alpha0LL = ref_state.alpha0_half[kc_surf]

    gm = GMV
    up = self.UpdVar
    en = self.EnvVar

    en.TKE.values[kc_surf] = get_surface_tke(Case.Sur.ustar, self.wstar, grid.z_half[kc_surf], Case.Sur.obukhov_length)
    get_GMV_CoVar(self, up.Area, up.W, up.W, en.W, en.W, en.TKE, gm.W.values, gm.W.values, gm.TKE.values)

    en.Hvar.values[kc_surf] = get_surface_variance(flux1 * alpha0LL, flux1 * alpha0LL, ustar, zLL, oblength)
    en.QTvar.values[kc_surf] = get_surface_variance(flux2 * alpha0LL, flux2 * alpha0LL, ustar, zLL, oblength)
    en.HQTcov.values[kc_surf] = get_surface_variance(flux1 * alpha0LL, flux2 * alpha0LL, ustar, zLL, oblength)
    get_GMV_CoVar(self, up.Area, up.H, up.H, en.H, en.H, en.Hvar, gm.H.values, gm.H.values, gm.Hvar.values)
    get_GMV_CoVar(self, up.Area, up.QT, up.QT, en.QT, en.QT, en.QTvar, gm.QT.values, gm.QT.values, gm.QTvar.values)
    get_GMV_CoVar(self, up.Area, up.H, up.QT, en.H, en.QT, en.HQTcov, gm.H.values, gm.QT.values, gm.HQTcov.values)
    return
end

# Find values of environmental variables by subtracting updraft values from grid mean values
# whichvals used to check which substep we are on--correspondingly use "GMV.SomeVar.value" (last timestep value)
function decompose_environment(self::EDMF_PrognosticTKE, GMV::GridMeanVariables)

    # first make sure the "bulkvalues" of the updraft variables are updated
    gm = GMV
    up = self.UpdVar
    en = self.EnvVar

    set_means(self, up, gm)
    grid = get_grid(self)
    @inbounds for k in real_center_indices(grid)
        a_bulk_c = up.Area.bulkvalues[k]
        val1 = 1 / (1 - a_bulk_c)
        val2 = a_bulk_c * val1

        en.Area.values[k] = 1 - a_bulk_c
        en.QT.values[k] = max(val1 * gm.QT.values[k] - val2 * up.QT.bulkvalues[k], 0) #Yair - this is here to prevent negative QT
        en.H.values[k] = val1 * gm.H.values[k] - val2 * up.H.bulkvalues[k]
    end
    @inbounds for k in real_face_indices(grid)
        # Assuming gm.W = 0!
        a_bulk_bcs = (; bottom = SetValue(sum(self.area_surface_bc)), top = SetValue(0))
        a_bulk_f = interpc2f(up.Area.bulkvalues, grid, k; a_bulk_bcs...)
        en.W.values[k] = -a_bulk_f / (1 - a_bulk_f) * up.W.bulkvalues[k]
    end

    get_GMV_CoVar(self, up.Area, up.W, up.W, en.W, en.W, en.TKE, gm.W.values, gm.W.values, gm.TKE.values)
    get_GMV_CoVar(self, up.Area, up.H, up.H, en.H, en.H, en.Hvar, gm.H.values, gm.H.values, gm.Hvar.values)
    get_GMV_CoVar(self, up.Area, up.QT, up.QT, en.QT, en.QT, en.QTvar, gm.QT.values, gm.QT.values, gm.QTvar.values)
    get_GMV_CoVar(self, up.Area, up.H, up.QT, en.H, en.QT, en.HQTcov, gm.H.values, gm.QT.values, gm.HQTcov.values)

    return
end

# Note: this assumes all variables are defined on half levels not full levels (i.e. phi, psi are not w)
# if covar_e.name is not "tke".
function get_GMV_CoVar(
    self::EDMF_PrognosticTKE,
    au::UpdraftVariable,
    ϕ_up::UpdraftVariable,
    ψ_up::UpdraftVariable,
    ϕ_en::EnvironmentVariable,
    ψ_en::EnvironmentVariable,
    covar_e::EnvironmentVariable_2m,
    ϕ_gm,
    ψ_gm,
    gmv_covar,
)

    grid = get_grid(self)
    ae = 1 .- au.bulkvalues
    is_tke = covar_e.name == "tke"
    tke_factor = is_tke ? 0.5 : 1

    if is_tke
        @inbounds for k in real_center_indices(grid)
            ϕ_en_dual = dual_faces(ϕ_en.values, grid, k)
            ϕ_gm_dual = dual_faces(ϕ_gm, grid, k)
            ψ_en_dual = dual_faces(ψ_en.values, grid, k)
            ψ_gm_dual = dual_faces(ψ_gm, grid, k)
            Δϕ_dual = ϕ_en_dual .- ϕ_gm_dual
            Δψ_dual = ψ_en_dual .- ψ_gm_dual
            Δϕ = interpf2c(Δϕ_dual, grid, k)
            Δψ = interpf2c(Δψ_dual, grid, k)

            gmv_covar[k] = tke_factor * ae[k] * Δϕ * Δψ + ae[k] * covar_e.values[k]
            @inbounds for i in xrange(self.n_updrafts)
                ϕ_up_dual = dual_faces(ϕ_up.values, grid, k, i)
                ϕ_gm_dual = dual_faces(ϕ_gm, grid, k)
                ψ_up_dual = dual_faces(ψ_up.values, grid, k, i)
                ψ_gm_dual = dual_faces(ψ_gm, grid, k)
                Δϕ_dual = ϕ_up_dual .- ϕ_gm_dual
                Δψ_dual = ψ_up_dual .- ψ_gm_dual
                Δϕ = interpf2c(Δϕ_dual, grid, k)
                Δψ = interpf2c(Δψ_dual, grid, k)
                gmv_covar[k] += tke_factor * au.values[i, k] * Δϕ * Δψ
            end
        end
    else

        @inbounds for k in real_center_indices(grid)
            Δϕ = ϕ_en.values[k] - ϕ_gm[k]
            Δψ = ψ_en.values[k] - ψ_gm[k]

            gmv_covar[k] = tke_factor * ae[k] * Δϕ * Δψ + ae[k] * covar_e.values[k]
            @inbounds for i in xrange(self.n_updrafts)
                Δϕ = ϕ_up.values[i, k] - ϕ_gm[k]
                Δψ = ψ_up.values[i, k] - ψ_gm[k]
                gmv_covar[k] += tke_factor * au.values[i, k] * Δϕ * Δψ
            end
        end
    end
    return
end


function get_env_covar_from_GMV(
    self::EDMF_PrognosticTKE,
    au::UpdraftVariable,
    ϕ_up::UpdraftVariable,
    ψ_up::UpdraftVariable,
    ϕ_en::EnvironmentVariable,
    ψ_en::EnvironmentVariable,
    covar_e::EnvironmentVariable_2m,
    ϕ_gm,
    ψ_gm,
    gmv_covar,
)

    grid = get_grid(self)
    ae = 1 .- au.bulkvalues
    is_tke = covar_e.name == "tke"
    tke_factor = is_tke ? 0.5 : 1

    if is_tke
        @inbounds for k in real_face_indices(grid)
            if ae[k] > 0.0
                ϕ_en_dual = dual_faces(ϕ_en.values, grid, k)
                ϕ_gm_dual = dual_faces(ϕ_gm, grid, k)
                ψ_en_dual = dual_faces(ψ_en.values, grid, k)
                ψ_gm_dual = dual_faces(ψ_gm, grid, k)
                Δϕ_dual = ϕ_en_dual .- ϕ_gm_dual
                Δψ_dual = ψ_en_dual .- ψ_gm_dual
                Δϕ = interpf2c(Δϕ_dual, grid, k)
                Δψ = interpf2c(Δψ_dual, grid, k)

                covar_e.values[k] = gmv_covar[k] - tke_factor * ae[k] * Δϕ * Δψ
                @inbounds for i in xrange(self.n_updrafts)
                    ϕ_up_dual = dual_faces(ϕ_up.values, grid, k, i)
                    ϕ_gm_dual = dual_faces(ϕ_gm, grid, k)
                    ψ_up_dual = dual_faces(ψ_up.values, grid, k, i)
                    ψ_gm_dual = dual_faces(ψ_gm, grid, k)
                    Δϕ_dual = ϕ_up_dual .- ϕ_gm_dual
                    Δψ_dual = ψ_up_dual .- ψ_gm_dual
                    Δϕ = interpf2c(Δϕ_dual, grid, k)
                    Δψ = interpf2c(Δψ_dual, grid, k)

                    covar_e.values[k] -= tke_factor * au.values[i, k] * Δϕ * Δψ
                end
                covar_e.values[k] = covar_e.values[k] / ae[k]
            else
                covar_e.values[k] = 0.0
            end
        end
    else
        @inbounds for k in real_center_indices(grid)
            if ae[k] > 0.0
                Δϕ = ϕ_en.values[k] - ϕ_gm[k]
                Δψ = ψ_en.values[k] - ψ_gm[k]

                covar_e.values[k] = gmv_covar[k] - tke_factor * ae[k] * Δϕ * Δψ
                @inbounds for i in xrange(self.n_updrafts)
                    Δϕ = ϕ_up.values[i, k] - ϕ_gm[k]
                    Δψ = ψ_up.values[i, k] - ψ_gm[k]

                    covar_e.values[k] -= tke_factor * au.values[i, k] * Δϕ * Δψ
                end
                covar_e.values[k] = covar_e.values[k] / ae[k]
            else
                covar_e.values[k] = 0.0
            end
        end
    end

    return
end

function compute_updraft_closures(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase)
    grid = get_grid(self)
    FT = eltype(grid)
    param_set = parameter_set(self)
    ref_state = reference_state(self)

    upd_cloud_diagnostics(self.UpdVar, ref_state)

    @inbounds for k in real_center_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)
            # entrainment
            if self.UpdVar.Area.values[i, k] > 0.0
                # compute ∇m at cell centers
                a_up_c = self.UpdVar.Area.values[i, k]
                w_up_c = interpf2c(self.UpdVar.W.values, grid, k, i)
                w_gm_c = interpf2c(GMV.W.values, grid, k)
                m = a_up_c * (w_up_c - w_gm_c)
                a_up_cut = ccut_upwind(self.UpdVar.Area.values, grid, k, i)
                w_up_cut = daul_f2c_upwind(self.UpdVar.W.values, grid, k, i)
                w_gm_cut = daul_f2c_upwind(GMV.W.values, grid, k)
                m_cut = a_up_cut .* (w_up_cut .- w_gm_cut)
                ∇m = FT(c∇_upwind(m_cut, grid, k; bottom = SetValue(0), top = FreeBoundary()))

                w_min = 0.001

                εδ_model = MoistureDeficitEntr(;
                    q_liq_up = self.UpdVar.QL.values[i, k],
                    q_liq_en = self.EnvVar.QL.values[k],
                    w_up = interpf2c(self.UpdVar.W.values, grid, k, i),
                    w_en = interpf2c(self.EnvVar.W.values, grid, k),
                    b_up = self.UpdVar.B.values[i, k],
                    b_en = self.EnvVar.B.values[k],
                    tke = self.EnvVar.TKE.values[k],
                    dMdz = ∇m,
                    M = m,
                    a_up = self.UpdVar.Area.values[i, k],
                    a_en = self.EnvVar.Area.values[k],
                    R_up = self.pressure_plume_spacing[i],
                    RH_up = self.UpdVar.RH.values[i, k],
                    RH_en = self.EnvVar.RH.values[k],
                )

                er = entr_detr(param_set, εδ_model)
                self.entr_sc[i, k] = er.ε_dyn
                self.detr_sc[i, k] = er.δ_dyn
                # stochastic closure
                sde_model = self.sde_model
                stoch_ε = stochastic_closure(param_set, sde_model, Entrainment())
                stoch_δ = stochastic_closure(param_set, sde_model, Detrainment())
                self.entr_sc[i, k] *= stoch_ε
                self.detr_sc[i, k] *= stoch_δ

                self.frac_turb_entr[i, k] = er.ε_turb
                self.horiz_K_eddy[i, k] = er.K_ε
            else
                self.entr_sc[i, k] = 0.0
                self.detr_sc[i, k] = 0.0
                self.frac_turb_entr[i, k] = 0.0
                self.horiz_K_eddy[i, k] = 0.0
            end
        end
    end

    kc_surf = kc_surface(grid)
    kc_toa = kc_top_of_atmos(grid)
    @inbounds for k in real_face_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)

            # pressure
            a_bcs = (; bottom = SetValue(self.area_surface_bc[i]), top = SetValue(0))
            a_kfull = interpc2f(self.UpdVar.Area.values, grid, k, i; a_bcs...)
            if a_kfull > 0.0
                B = self.UpdVar.B.values
                b_bcs = (; bottom = SetValue(B[i, kc_surf]), top = SetValue(B[i, kc_toa]))
                b_kfull = interpc2f(self.UpdVar.B.values, grid, k, i; b_bcs...)
                w_cut = fcut(self.UpdVar.W.values, grid, k, i)
                ∇w_up = f∇(w_cut, grid, k; bottom = SetValue(0), top = SetGradient(0))
                asp_ratio = 1.0
                self.nh_pressure_b[i, k], self.nh_pressure_adv[i, k], self.nh_pressure_drag[i, k] =
                    perturbation_pressure(
                        param_set,
                        self.UpdVar.updraft_top[i],
                        a_kfull,
                        b_kfull,
                        ref_state.rho0[k],
                        self.UpdVar.W.values[i, k],
                        ∇w_up,
                        self.EnvVar.W.values[k],
                        asp_ratio,
                    )
            else
                self.nh_pressure_b[i, k] = 0.0
                self.nh_pressure_adv[i, k] = 0.0
                self.nh_pressure_drag[i, k] = 0.0
            end
            self.nh_pressure[i, k] = self.nh_pressure_b[i, k] + self.nh_pressure_adv[i, k] + self.nh_pressure_drag[i, k]
        end
    end
    return
end

function compute_pressure_plume_spacing(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase)

    param_set = parameter_set(self)
    H_up_min = CPEDMF.H_up_min(param_set)
    @inbounds for i in xrange(self.n_updrafts)
        self.pressure_plume_spacing[i] =
            max(self.aspect_ratio * self.UpdVar.updraft_top[i], H_up_min * self.aspect_ratio)
    end
    return
end

function zero_area_fraction_cleanup(self::EDMF_PrognosticTKE, GMV::GridMeanVariables)

    grid = get_grid(self)
    @inbounds for k in real_center_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)
            if self.UpdVar.Area.values[i, k] < self.minimum_area
                self.UpdVar.Area.values[i, k] = 0.0
                self.UpdVar.B.values[i, k] = GMV.B.values[k]
                self.UpdVar.H.values[i, k] = GMV.H.values[k]
                self.UpdVar.QT.values[i, k] = GMV.QT.values[k]
                self.UpdVar.T.values[i, k] = GMV.T.values[k]
                self.UpdVar.QL.values[i, k] = GMV.QL.values[k]
            end
        end

        if sum(self.UpdVar.Area.values[:, k]) == 0.0
            self.EnvVar.B.values[k] = GMV.B.values[k]
            self.EnvVar.H.values[k] = GMV.H.values[k]
            self.EnvVar.QT.values[k] = GMV.QT.values[k]
            self.EnvVar.T.values[k] = GMV.T.values[k]
            self.EnvVar.QL.values[k] = GMV.QL.values[k]
        end
    end

    @inbounds for k in real_face_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)
            a_bcs = (; bottom = SetValue(self.area_surface_bc[i]), top = SetValue(0))
            a_up_f_i = interpc2f(self.UpdVar.Area.values, grid, k, i; a_bcs...)
            if a_up_f_i < self.minimum_area
                self.UpdVar.W.values[i, k] = GMV.W.values[k]
            end
        end

        a_up_f = map(1:(self.n_updrafts)) do i
            a_bcs = (; bottom = SetValue(self.area_surface_bc[i]), top = SetValue(0))
            interpc2f(self.UpdVar.Area.values, grid, k, i; a_bcs...)
        end

        if sum(a_up_f) == 0.0
            self.EnvVar.W.values[k] = GMV.W.values[k]
        end
    end

    return
end

function solve_updraft(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, TS::TimeStepping)
    grid = get_grid(self)
    param_set = parameter_set(GMV)
    ref_state = reference_state(self)
    kc_surf = kc_surface(grid)
    kf_surf = kf_surface(grid)
    dti_ = 1.0 / TS.dt
    Δt = TS.dt
    sa = eos_struct()

    a_up = self.UpdVar.Area.values
    a_up_new = self.UpdVar.Area.new
    w_up = self.UpdVar.W.values
    w_up_new = self.UpdVar.W.new
    ρ_0_c = ref_state.rho0_half
    ρ_0_f = ref_state.rho0
    au_lim = self.max_area

    @inbounds for i in xrange(self.n_updrafts)
        self.entr_sc[i, kc_surf] = self.entr_surface_bc
        self.detr_sc[i, kc_surf] = self.detr_surface_bc
        w_up_new[i, kf_surf] = self.w_surface_bc[i]
        a_up_new[i, kc_surf] = self.area_surface_bc[i]
    end

    # Solve for updraft area fraction
    @inbounds for k in real_center_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)
            is_surface_center(grid, k) && continue
            w_up_c = interpf2c(w_up, grid, k, i)
            adv = upwind_advection_area(ρ_0_c, a_up[i, :], w_up[i, :], grid, k)

            a_up_c = a_up[i, k]
            entr_term = a_up_c * w_up_c * (self.entr_sc[i, k])
            detr_term = a_up_c * w_up_c * (-self.detr_sc[i, k])
            a_tendencies = adv + entr_term + detr_term

            a_up_candidate = max(a_up_c + Δt * a_tendencies, 0)

            if a_up_candidate > au_lim
                a_up_candidate = au_lim
                a_up_div = a_up_c > 0.0 ? a_up_c : au_lim
                self.detr_sc[i, k] = (((au_lim - a_up_c) * dti_ - adv - entr_term) / (-a_up_div * w_up_c))
            end
            a_up_new[i, k] = a_up_candidate
        end
    end

    entr_w_c = self.entr_sc .+ self.frac_turb_entr
    detr_w_c = self.detr_sc .+ self.frac_turb_entr


    # Solve for updraft velocity
    @inbounds for k in real_face_indices(grid)
        is_surface_face(grid, k) && continue
        @inbounds for i in xrange(self.n_updrafts)
            a_up_bcs = (; bottom = SetValue(self.area_surface_bc[i]), top = SetZeroGradient())
            anew_k = interpc2f(a_up_new, grid, k, i; a_up_bcs...)

            if anew_k >= self.minimum_area
                a_k = interpc2f(a_up, grid, k, i; a_up_bcs...)
                # We know that, since W = 0 at z = 0, these BCs should
                # not matter in the end:
                entr_w = interpc2f(entr_w_c, grid, k, i; bottom = SetValue(0), top = SetValue(0))
                detr_w = interpc2f(detr_w_c, grid, k, i; bottom = SetValue(0), top = SetValue(0))
                B_k = interpc2f(self.UpdVar.B.values, grid, k, i; bottom = SetValue(0), top = SetValue(0))

                adv = upwind_advection_velocity(ρ_0_f, a_up[i, :], w_up[i, :], grid, k; a_up_bcs)
                exch = (ρ_0_f[k] * a_k * w_up[i, k] * (entr_w * self.EnvVar.W.values[k] - detr_w * w_up[i, k]))
                buoy = ρ_0_f[k] * a_k * B_k
                w_tendencies = -adv + exch + buoy + self.nh_pressure[i, k]
                w_up_new[i, k] = (ρ_0_f[k] * a_k * w_up[i, k] + Δt * w_tendencies) / (ρ_0_f[k] * anew_k)

                w_up_new[i, k] = max(w_up_new[i, k], 0)
                # TODO: remove a_up_new from this loop.
                if w_up_new[i, k] <= 0.0
                    if !(k > size(a_up_new, 2))
                        a_up_new[i, k] = 0
                    end
                end
            else
                w_up_new[i, k] = 0
                if !(k > size(a_up_new, 2))
                    a_up_new[i, k] = 0
                end
            end
        end
    end

    # Solve for θ_liq_ice & q_tot
    @inbounds for k in real_center_indices(grid)
        @inbounds for i in xrange(self.n_updrafts)
            if is_surface_center(grid, k)
                # at the surface
                if a_up_new[i, k] >= self.minimum_area
                    self.UpdVar.H.new[i, k] = self.h_surface_bc[i]
                    self.UpdVar.QT.new[i, k] = self.qt_surface_bc[i]
                else
                    self.UpdVar.H.new[i, k] = GMV.H.values[k]
                    self.UpdVar.QT.new[i, k] = GMV.QT.values[k]
                end
                continue
            end

            # write the discrete equations in form
            # c1 * phi_new[k] = c2 * phi[k] + c3 * phi[k-1] + c4 * ϕ_enntr
            if a_up_new[i, k] >= self.minimum_area
                w_up_c = interpf2c(w_up, grid, k, i)
                m_k = (ρ_0_c[k] * a_up[i, k] * w_up_c)

                adv = upwind_advection_scalar(ρ_0_c, a_up[i, :], w_up[i, :], self.UpdVar.H.values[i, :], grid, k)
                entr = entr_w_c[i, k] * self.EnvVar.H.values[k]
                detr = detr_w_c[i, k] * self.UpdVar.H.values[i, k]
                θ_liq_ice_tendencies = -adv + m_k * (entr - detr)
                self.UpdVar.H.new[i, k] =
                    (ρ_0_c[k] * a_up[i, k] * self.UpdVar.H.values[i, k] + Δt * θ_liq_ice_tendencies) /
                    (ρ_0_c[k] * a_up_new[i, k])

                adv = upwind_advection_scalar(ρ_0_c, a_up[i, :], w_up[i, :], self.UpdVar.QT.values[i, :], grid, k)
                entr = entr_w_c[i, k] * self.EnvVar.QT.values[k]
                detr = detr_w_c[i, k] * self.UpdVar.QT.values[i, k]
                q_tot_tendencies = -adv + m_k * (entr - detr)
                self.UpdVar.QT.new[i, k] = max(
                    (ρ_0_c[k] * a_up[i, k] * self.UpdVar.QT.values[i, k] + Δt * q_tot_tendencies) /
                    (ρ_0_c[k] * a_up_new[i, k]),
                    0.0,
                )

            else
                self.UpdVar.H.new[i, k] = GMV.H.values[k]
                self.UpdVar.QT.new[i, k] = GMV.QT.values[k]
            end
        end
    end

    return
end

# After updating the updraft variables themselves
# 1. compute the mass fluxes (currently not stored as class members, probably will want to do this
# for output purposes)
# 2. Apply mass flux tendencies and updraft microphysical tendencies to GMV.SomeVar.Values (old time step values)
# mass flux tendency is computed as 1st order upwind

function compute_GMV_MF(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, TS::TimeStepping)
    grid = get_grid(self)
    ref_state = reference_state(self)
    rho0 = ref_state.rho0
    kf_surf = kf_surface(grid)
    mf_tend_h = 0.0
    mf_tend_qt = 0.0
    ae = 1 .- self.UpdVar.Area.bulkvalues # area of environment

    self.massflux_h .= 0.0
    self.massflux_qt .= 0.0

    # Compute the mass flux and associated scalar fluxes
    @inbounds for i in xrange(self.n_updrafts)
        self.m[i, kf_surf] = 0.0
        a_up_bcs = (; bottom = SetValue(self.area_surface_bc[i]), top = SetZeroGradient())
        @inbounds for k in real_face_indices(grid)
            a_up = interpc2f(self.UpdVar.Area.values, grid, k, i; a_up_bcs...)
            a_en = interpc2f(ae, grid, k; a_up_bcs...)
            self.m[i, k] = rho0[k] * a_up * a_en * (self.UpdVar.W.values[i, k] - self.EnvVar.W.values[k])
        end
    end


    self.massflux_h[kf_surf] = 0.0
    self.massflux_qt[kf_surf] = 0.0

    @inbounds for k in real_face_indices(grid)
        self.massflux_h[k] = 0.0
        self.massflux_qt[k] = 0.0
        # We know that, since W = 0 at z = 0, m = 0 also, and
        # therefore θ_liq_ice / q_tot values do not matter
        m_bcs = (; bottom = SetValue(0), top = SetValue(0))
        h_en_f = interpc2f(self.EnvVar.H.values, grid, k; m_bcs...)
        qt_en_f = interpc2f(self.EnvVar.QT.values, grid, k; m_bcs...)
        @inbounds for i in xrange(self.n_updrafts)
            h_up_f = interpc2f(self.UpdVar.H.values, grid, k, i; m_bcs...)
            qt_up_f = interpc2f(self.UpdVar.QT.values, grid, k, i; m_bcs...)
            self.massflux_h[k] += self.m[i, k] * (h_up_f - h_en_f)
            self.massflux_qt[k] += self.m[i, k] * (qt_up_f - qt_en_f)
        end
    end

    # Compute the  mass flux tendencies
    # Adjust the values of the grid mean variables
    @inbounds for k in real_center_indices(grid)
        mf_tend_h_dual = dual_faces(self.massflux_h, grid, k)
        mf_tend_qt_dual = dual_faces(self.massflux_qt, grid, k)

        ∇mf_tend_h = ∇f2c(mf_tend_h_dual, grid, k)
        ∇mf_tend_qt = ∇f2c(mf_tend_qt_dual, grid, k)

        mf_tend_h = -∇mf_tend_h * ref_state.alpha0_half[k]
        mf_tend_qt = -∇mf_tend_qt * ref_state.alpha0_half[k]

        # Prepare the output
        self.massflux_tendency_h[k] = mf_tend_h
        self.massflux_tendency_qt[k] = mf_tend_qt
    end
    return
end

# Update the grid mean variables with the tendency due to eddy diffusion
# Km and Kh have already been updated
# 2nd order finite differences plus implicit time step allows solution with tridiagonal matrix solver
function update_GMV_ED(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase, TS::TimeStepping)
    grid = get_grid(self)
    nzg = grid.nzg
    nz = grid.nz
    dzi = grid.dzi
    ref_state = reference_state(self)
    a = center_field(grid) # for tridiag solver
    b = center_field(grid) # for tridiag solver
    c = center_field(grid) # for tridiag solver
    x = center_field(grid) # for tridiag solver
    ae = 1 .- self.UpdVar.Area.bulkvalues # area of environment
    rho_ae_K = face_field(grid)
    KM = diffusivity_m(self).values
    KH = diffusivity_h(self).values
    aeKM = ae .* KM
    aeKH = ae .* KH
    kc_surf = kc_surface(grid)
    kc_toa = kc_top_of_atmos(grid)
    kf_surf = kf_surface(grid)
    aeKM_bcs = (; bottom = SetValue(aeKM[kc_surf]), top = SetValue(aeKM[kc_toa]))
    aeKH_bcs = (; bottom = SetValue(aeKH[kc_surf]), top = SetValue(aeKH[kc_toa]))

    @inbounds for k in real_face_indices(grid)
        rho_ae_K[k] = interpc2f(aeKH, grid, k; aeKH_bcs...) * ref_state.rho0[k]
    end

    # Matrix is the same for all variables that use the same eddy diffusivity, we can construct once and reuse
    construct_tridiag_diffusion(grid, TS.dt, rho_ae_K, ref_state.rho0_half, ae, a, b, c)
    # Solve QT
    @inbounds for k in real_center_indices(grid)
        x[k] = self.EnvVar.QT.values[k]
        if is_surface_center(grid, k)
            x[k] = x[k] + TS.dt * Case.Sur.rho_qtflux * dzi * ref_state.alpha0_half[k] / ae[k]
        end
    end
    cinterior = real_center_indices(grid)
    x[cinterior] .= tridiag_solve(x[cinterior], a[cinterior], b[cinterior], c[cinterior])

    @inbounds for k in real_center_indices(grid)
        mf_tend_qt_dual = dual_faces(self.massflux_qt, grid, k)
        ∇mf_tend_qt = ∇f2c(mf_tend_qt_dual, grid, k)
        mf_tend_qt = -∇mf_tend_qt * ref_state.alpha0_half[k]

        GMV.QT.new[k] = max(
            (GMV.QT.values[k] + TS.dt * mf_tend_qt + self.UpdThermo.prec_source_qt_tot[k]) +
            ae[k] * (x[k] - self.EnvVar.QT.values[k]) +
            self.EnvThermo.prec_source_qt[k] +
            self.rainphysics.rain_evap_source_qt[k],
            0.0,
        )
        self.diffusive_tendency_qt[k] =
            (GMV.QT.new[k] - (GMV.QT.values[k] + TS.dt * mf_tend_qt + self.UpdThermo.prec_source_qt_tot[k])) * TS.dti
    end
    # get the diffusive flux
    q_bc = -Case.Sur.rho_qtflux / rho_ae_K[kf_surf]
    @inbounds for k in real_center_indices(grid)
        q_cut = ccut(self.EnvVar.QT.values, grid, k)
        ∇q_tot = c∇(q_cut, grid, k; bottom = SetGradient(q_bc), top = SetGradient(0))
        self.diffusive_flux_qt[k] = -0.5 * ref_state.rho0_half[k] * ae[k] * KH[k] * ∇q_tot
    end

    # Solve H
    @inbounds for k in real_center_indices(grid)
        x[k] = self.EnvVar.H.values[k]
        if is_surface_center(grid, k)
            x[k] = x[k] + TS.dt * Case.Sur.rho_hflux * dzi * ref_state.alpha0_half[k] / ae[k]
        end
    end
    x[cinterior] .= tridiag_solve(x[cinterior], a[cinterior], b[cinterior], c[cinterior])
    @inbounds for k in real_center_indices(grid)
        mf_tend_h_dual = dual_faces(self.massflux_h, grid, k)
        ∇mf_tend_h = ∇f2c(mf_tend_h_dual, grid, k)
        mf_tend_h = -∇mf_tend_h * ref_state.alpha0_half[k]

        GMV.H.new[k] =
            (GMV.H.values[k] + TS.dt * mf_tend_h + self.UpdThermo.prec_source_h_tot[k]) +
            ae[k] * (x[k] - self.EnvVar.H.values[k]) +
            self.EnvThermo.prec_source_h[k] +
            self.rainphysics.rain_evap_source_h[k]
        self.diffusive_tendency_h[k] =
            (GMV.H.new[k] - (GMV.H.values[k] + TS.dt * mf_tend_h + self.UpdThermo.prec_source_h_tot[k])) * TS.dti
    end
    # get the diffusive flux
    θ_liq_ice_bc = -Case.Sur.rho_hflux / rho_ae_K[kf_surf]
    @inbounds for k in real_center_indices(grid)
        θ_liq_ice_cut = ccut(self.EnvVar.H.values, grid, k)
        ∇θ_liq_ice = c∇(θ_liq_ice_cut, grid, k; bottom = SetGradient(θ_liq_ice_bc), top = SetGradient(0))
        self.diffusive_flux_h[k] = -0.5 * ref_state.rho0_half[k] * ae[k] * KH[k] * ∇θ_liq_ice
    end

    # Solve U
    @inbounds for k in real_face_indices(grid)
        rho_ae_K[k] = interpc2f(aeKM, grid, k; aeKM_bcs...) * ref_state.rho0[k]
    end

    # Matrix is the same for all variables that use the same eddy diffusivity, we can construct once and reuse
    construct_tridiag_diffusion(grid, TS.dt, rho_ae_K, ref_state.rho0_half, ae, a, b, c)
    @inbounds for k in real_center_indices(grid)
        x[k] = GMV.U.values[k]
        if is_surface_center(grid, k)
            x[k] = x[k] + TS.dt * Case.Sur.rho_uflux * dzi * ref_state.alpha0_half[k] / ae[k]
        end
    end
    x[cinterior] .= tridiag_solve(x[cinterior], a[cinterior], b[cinterior], c[cinterior])

    @inbounds for k in real_center_indices(grid)
        GMV.U.new[k] = x[k]
    end
    u_bc = -Case.Sur.rho_uflux / rho_ae_K[kf_surf]
    @inbounds for k in real_center_indices(grid)
        u_cut = ccut(GMV.U.values, grid, k)
        ∇u = c∇(u_cut, grid, k; bottom = SetGradient(u_bc), top = SetGradient(0))
        self.diffusive_flux_u[k] = -0.5 * ref_state.rho0_half[k] * ae[k] * KM[k] * ∇u
    end

    # Solve V
    @inbounds for k in real_center_indices(grid)
        x[k] = GMV.V.values[k]
        if is_surface_center(grid, k)
            x[k] = x[k] + TS.dt * Case.Sur.rho_vflux * dzi * ref_state.alpha0_half[k] / ae[k]
        end
    end
    x[cinterior] .= tridiag_solve(x[cinterior], a[cinterior], b[cinterior], c[cinterior])
    @inbounds for k in real_center_indices(grid)
        GMV.V.new[k] = x[k]
    end
    v_bc = -Case.Sur.rho_vflux / rho_ae_K[kf_surf]
    @inbounds for k in real_center_indices(grid)
        v_cut = ccut(GMV.V.values, grid, k)
        ∇v = c∇(v_cut, grid, k; bottom = SetGradient(v_bc), top = SetGradient(0))
        self.diffusive_flux_v[k] = -0.5 * ref_state.rho0_half[k] * ae[k] * KM[k] * ∇v
    end

    return
end

function compute_tke_pressure(self::EDMF_PrognosticTKE)
    grid = get_grid(self)

    @inbounds for k in real_center_indices(grid)
        self.EnvVar.TKE.press[k] = 0.0
        @inbounds for i in xrange(self.n_updrafts)
            w_up_c = interpf2c(self.UpdVar.W.values, grid, k, i)
            w_en_c = interpf2c(self.EnvVar.W.values, grid, k)
            press_c = interpf2c(self.nh_pressure, grid, k, i)
            self.EnvVar.TKE.press[k] += (w_en_c - w_up_c) * press_c
        end
    end
    return
end

function update_GMV_diagnostics(self::EDMF_PrognosticTKE, GMV::GridMeanVariables)

    grid = get_grid(self)
    p0_half = reference_state(self).p0_half
    a_up_bulk = self.UpdVar.Area.bulkvalues
    @inbounds for k in real_center_indices(grid)
        GMV.QL.values[k] = (a_up_bulk[k] * self.UpdVar.QL.bulkvalues[k] + (1 - a_up_bulk[k]) * self.EnvVar.QL.values[k])
        GMV.T.values[k] = (a_up_bulk[k] * self.UpdVar.T.bulkvalues[k] + (1 - a_up_bulk[k]) * self.EnvVar.T.values[k])
        GMV.B.values[k] = (a_up_bulk[k] * self.UpdVar.B.bulkvalues[k] + (1 - a_up_bulk[k]) * self.EnvVar.B.values[k])
    end

    return
end

function compute_covariance_rhs(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase, TS::TimeStepping)

    gm = GMV
    up = self.UpdVar
    en = self.EnvVar
    compute_covariance_entr(self, en.TKE, up.W, up.W, en.W, en.W, gm.W, gm.W)
    compute_covariance_shear(self, gm, en.TKE, up.W.values, up.W.values, en.W.values, en.W.values)
    compute_covariance_interdomain_src(self, up.Area, up.W, up.W, en.W, en.W, en.TKE)
    compute_tke_pressure(self)
    compute_covariance_entr(self, en.Hvar, up.H, up.H, en.H, en.H, gm.H, gm.H)
    compute_covariance_entr(self, en.QTvar, up.QT, up.QT, en.QT, en.QT, gm.QT, gm.QT)
    compute_covariance_entr(self, en.HQTcov, up.H, up.QT, en.H, en.QT, gm.H, gm.QT)
    compute_covariance_shear(self, gm, en.Hvar, up.H.values, up.H.values, en.H.values, en.H.values)
    compute_covariance_shear(self, gm, en.QTvar, up.QT.values, up.QT.values, en.QT.values, en.QT.values)
    compute_covariance_shear(self, gm, en.HQTcov, up.H.values, up.QT.values, en.H.values, en.QT.values)
    compute_covariance_interdomain_src(self, up.Area, up.H, up.H, en.H, en.H, en.Hvar)
    compute_covariance_interdomain_src(self, up.Area, up.QT, up.QT, en.QT, en.QT, en.QTvar)
    compute_covariance_interdomain_src(self, up.Area, up.H, up.QT, en.H, en.QT, en.HQTcov)
    compute_covariance_rain(self, TS, gm) # need to update this one

    GMV_third_m(self, gm.H_third_m, en.Hvar, en.H, up.H)
    GMV_third_m(self, gm.QT_third_m, en.QTvar, en.QT, up.QT)
    GMV_third_m(self, gm.W_third_m, en.TKE, en.W, up.W)

    reset_surface_covariance(self, gm, Case)
    return
end

function update_covariance(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase, TS::TimeStepping)
    gm = GMV
    up = self.UpdVar
    en = self.EnvVar
    update_covariance_ED(self, gm, Case, TS, gm.W, gm.W, gm.TKE, en.TKE, en.W, en.W, up.W, up.W)
    update_covariance_ED(self, gm, Case, TS, gm.H, gm.H, gm.Hvar, en.Hvar, en.H, en.H, up.H, up.H)
    update_covariance_ED(self, gm, Case, TS, gm.QT, gm.QT, gm.QTvar, en.QTvar, en.QT, en.QT, up.QT, up.QT)
    update_covariance_ED(self, gm, Case, TS, gm.H, gm.QT, gm.HQTcov, en.HQTcov, en.H, en.QT, up.H, up.QT)
    return
end

function initialize_covariance(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, Case::CasesBase)

    ws = self.wstar
    us = Case.Sur.ustar
    zs = self.zi
    grid = get_grid(self)
    kc_surf = kc_surface(grid)

    reset_surface_covariance(self, GMV, Case)

    # grid-mean tke closure over all but z:
    tke_gm(z) = ws * 1.3 * cbrt((us * us * us) / (ws * ws * ws) + 0.6 * z / zs) * sqrt(max(1 - z / zs, 0))


    if ws > 0.0
        @inbounds for k in real_center_indices(grid)
            z = grid.z_half[k]
            GMV.TKE.values[k] = tke_gm(z)
        end
    end
    # TKE initialization from Beare et al, 2006
    if Case.casename == "GABLS"
        @inbounds for k in real_center_indices(grid)
            z = grid.z_half[k]
            if (z <= 250.0)
                GMV.TKE.values[k] = 0.4 * (1.0 - z / 250.0) * (1.0 - z / 250.0) * (1.0 - z / 250.0)
            end
        end

    elseif Case.casename == "Bomex"
        @inbounds for k in real_center_indices(grid)
            z = grid.z_half[k]
            if (z <= 2500.0)
                GMV.TKE.values[k] = 1.0 - z / 3000.0
            end
        end

    elseif Case.casename == "Soares" || Case.casename == "Nieuwstadt"
        @inbounds for k in real_center_indices(grid)
            z = grid.z_half[k]
            if (z <= 1600.0)
                GMV.TKE.values[k] = 0.1 * 1.46 * 1.46 * (1.0 - z / 1600.0)
            end
        end
    end

    if ws > 0.0
        @inbounds for k in real_center_indices(grid)
            z = grid.z_half[k]
            # need to rethink of how to initilize the covarinace profiles - for now took the TKE profile
            GMV.Hvar.values[k] = GMV.Hvar.values[kc_surf] * tke_gm(z)
            GMV.QTvar.values[k] = GMV.QTvar.values[kc_surf] * tke_gm(z)
            GMV.HQTcov.values[k] = GMV.HQTcov.values[kc_surf] * tke_gm(z)
        end
    else
        @inbounds for k in real_center_indices(grid)
            GMV.Hvar.values[k] = 0.0
            GMV.QTvar.values[k] = 0.0
            GMV.HQTcov.values[k] = 0.0
        end
    end

    # TKE initialization from Beare et al, 2006
    if Case.casename == "GABLS"
        @inbounds for k in real_center_indices(grid)
            z = grid.z_half[k]
            if (z <= 250.0)
                GMV.Hvar.values[k] = 0.4 * (1.0 - z / 250.0) * (1.0 - z / 250.0) * (1.0 - z / 250.0)
            end
            GMV.QTvar.values[k] = 0.0
            GMV.HQTcov.values[k] = 0.0
        end
    end

    @inbounds for k in real_center_indices(grid)
        self.EnvVar.TKE.values[k] = GMV.TKE.values[k]
        self.EnvVar.Hvar.values[k] = GMV.Hvar.values[k]
        self.EnvVar.QTvar.values[k] = GMV.QTvar.values[k]
        self.EnvVar.HQTcov.values[k] = GMV.HQTcov.values[k]
    end
    return
end

function compute_covariance_shear(
    self::EDMF_PrognosticTKE,
    GMV::GridMeanVariables,
    Covar::EnvironmentVariable_2m,
    UpdVar1,
    UpdVar2,
    EnvVar1,
    EnvVar2,
)

    grid = get_grid(self)
    ae = 1 .- self.UpdVar.Area.bulkvalues
    diff_var1 = 0.0
    diff_var2 = 0.0
    KH = diffusivity_h(self).values
    rho0_half = reference_state(self).rho0_half
    is_tke = Covar.name == "tke"
    tke_factor = is_tke ? 0.5 : 1
    k_eddy = is_tke ? diffusivity_m(self).values : diffusivity_h(self).values

    if is_tke
        @inbounds for k in real_center_indices(grid)
            v_cut = ccut(GMV.V.values, grid, k)
            ∇v = c∇(v_cut, grid, k; bottom = Extrapolate(), top = SetGradient(0))

            u_cut = ccut(GMV.U.values, grid, k)
            ∇u = c∇(u_cut, grid, k; bottom = Extrapolate(), top = SetGradient(0))

            var2_dual = dual_faces(EnvVar2, grid, k)
            var1_dual = dual_faces(EnvVar1, grid, k)

            ∇var2 = ∇f2c(var2_dual, grid, k; bottom = SetValue(0), top = SetGradient(0))
            ∇var1 = ∇f2c(var1_dual, grid, k; bottom = SetValue(0), top = SetGradient(0))

            Covar.shear[k] = tke_factor * 2 * (rho0_half[k] * ae[k] * k_eddy[k] * (∇var1 * ∇var2 + ∇u^2 + ∇v^2))
        end
    else
        @inbounds for k in real_center_indices(grid)
            # Defined correctly only for covariance between half-level variables.
            var1_cut = ccut(EnvVar1, grid, k)
            ∇var1 = c∇(var1_cut, grid, k; bottom = Extrapolate(), top = SetGradient(0))

            var2_cut = ccut(EnvVar2, grid, k)
            ∇var2 = c∇(var2_cut, grid, k; bottom = Extrapolate(), top = SetGradient(0))

            Covar.shear[k] = tke_factor * 2 * (rho0_half[k] * ae[k] * k_eddy[k] * (∇var1 * ∇var2))
        end
    end
    return
end

function compute_covariance_interdomain_src(
    self::EDMF_PrognosticTKE,
    au::UpdraftVariable,
    ϕ_up::UpdraftVariable,
    ψ_up::UpdraftVariable,
    ϕ_en::EnvironmentVariable,
    ψ_en::EnvironmentVariable,
    Covar::EnvironmentVariable_2m,
)

    is_tke = Covar.name == "tke"
    tke_factor = is_tke ? 0.5 : 1
    grid = get_grid(self)
    if is_tke
        @inbounds for k in real_center_indices(grid)
            Covar.interdomain[k] = 0.0
            @inbounds for i in xrange(self.n_updrafts)
                Δϕ = interpf2c(ϕ_up.values, grid, k, i) - interpf2c(ϕ_en.values, grid, k)
                Δψ = interpf2c(ψ_up.values, grid, k, i) - interpf2c(ψ_en.values, grid, k)

                Covar.interdomain[k] += tke_factor * au.values[i, k] * (1.0 - au.values[i, k]) * Δϕ * Δψ
            end
        end
    else
        @inbounds for k in real_center_indices(grid)
            Covar.interdomain[k] = 0.0
            @inbounds for i in xrange(self.n_updrafts)
                Δϕ = ϕ_up.values[i, k] - ϕ_en.values[k]
                Δψ = ψ_up.values[i, k] - ψ_en.values[k]
                Covar.interdomain[k] += tke_factor * au.values[i, k] * (1.0 - au.values[i, k]) * Δϕ * Δψ
            end
        end
    end
    return
end

function compute_covariance_entr(
    self::EDMF_PrognosticTKE,
    Covar::EnvironmentVariable_2m,
    UpdVar1::UpdraftVariable,
    UpdVar2::UpdraftVariable,
    EnvVar1::EnvironmentVariable,
    EnvVar2::EnvironmentVariable,
    GmvVar1::VariablePrognostic,
    GmvVar2::VariablePrognostic,
)

    grid = get_grid(self)
    ref_state = reference_state(self)
    rho0_half = ref_state.rho0_half
    is_tke = Covar.name == "tke"
    tke_factor = is_tke ? 0.5 : 1
    a_up = self.UpdVar.Area.values

    @inbounds for k in real_center_indices(grid)
        Covar.entr_gain[k] = 0.0
        Covar.detr_loss[k] = 0.0
        @inbounds for i in xrange(self.n_updrafts)
            if self.UpdVar.Area.values[i, k] > self.minimum_area
                R_up = self.pressure_plume_spacing[i]
                updvar1 = is_tke ? interpf2c(UpdVar1.values, grid, k, i) : UpdVar1.values[i, k]
                updvar2 = is_tke ? interpf2c(UpdVar2.values, grid, k, i) : UpdVar2.values[i, k]
                envvar1 = is_tke ? interpf2c(EnvVar1.values, grid, k) : EnvVar1.values[k]
                envvar2 = is_tke ? interpf2c(EnvVar2.values, grid, k) : EnvVar2.values[k]
                gmvvar1 = is_tke ? interpf2c(GmvVar1.values, grid, k) : GmvVar1.values[k]
                gmvvar2 = is_tke ? interpf2c(GmvVar2.values, grid, k) : GmvVar2.values[k]

                eps_turb = self.frac_turb_entr[i, k]

                w_u = interpf2c(self.UpdVar.W.values, grid, k, i)
                dynamic_entr =
                    tke_factor *
                    rho0_half[k] *
                    a_up[i, k] *
                    abs(w_u) *
                    self.detr_sc[i, k] *
                    (updvar1 - envvar1) *
                    (updvar2 - envvar2)
                turbulent_entr =
                    tke_factor *
                    rho0_half[k] *
                    a_up[i, k] *
                    abs(w_u) *
                    eps_turb *
                    ((envvar1 - gmvvar1) * (updvar2 - envvar2) + (envvar2 - gmvvar2) * (updvar1 - envvar1))
                Covar.entr_gain[k] += dynamic_entr + turbulent_entr
                Covar.detr_loss[k] +=
                    tke_factor *
                    rho0_half[k] *
                    a_up[i, k] *
                    abs(w_u) *
                    (self.entr_sc[i, k] + eps_turb) *
                    Covar.values[k]
            end
        end
    end

    return
end

function compute_covariance_detr(self::EDMF_PrognosticTKE, Covar::EnvironmentVariable_2m)
    grid = get_grid(self)
    rho0_half = reference_state(self).rho0_half
    @inbounds for k in real_center_indices(grid)
        Covar.detr_loss[k] = 0.0
        @inbounds for i in xrange(self.n_updrafts)
            w_up_c = interpf2c(self.UpdVar.W.values, grid, k, i)
            Covar.detr_loss[k] += self.UpdVar.Area.values[i, k] * abs(w_up_c) * self.entr_sc[i, k]
        end
        Covar.detr_loss[k] *= rho0_half[k] * Covar.values[k]
    end
    return
end

function compute_covariance_rain(self::EDMF_PrognosticTKE, TS::TimeStepping, GMV::GridMeanVariables)
    # TODO defined again in compute_covariance_shear and compute_covaraince
    grid = get_grid(self)
    ae = 1 .- self.UpdVar.Area.bulkvalues # area of environment
    rho0_half = reference_state(self).rho0_half

    @inbounds for k in real_center_indices(grid)
        self.EnvVar.TKE.rain_src[k] = 0.0
        self.EnvVar.Hvar.rain_src[k] = rho0_half[k] * ae[k] * 2.0 * self.EnvThermo.Hvar_rain_dt[k] * TS.dti
        self.EnvVar.QTvar.rain_src[k] = rho0_half[k] * ae[k] * 2.0 * self.EnvThermo.QTvar_rain_dt[k] * TS.dti
        self.EnvVar.HQTcov.rain_src[k] = rho0_half[k] * ae[k] * self.EnvThermo.HQTcov_rain_dt[k] * TS.dti
    end

    return
end

function compute_covariance_dissipation(self::EDMF_PrognosticTKE, Covar::EnvironmentVariable_2m)
    grid = get_grid(self)
    param_set = parameter_set(self)
    c_d = CPEDMF.c_d(param_set)
    ae = 1 .- self.UpdVar.Area.bulkvalues
    rho0_half = reference_state(self).rho0_half

    @inbounds for k in real_center_indices(grid)
        Covar.dissipation[k] = (
            rho0_half[k] * ae[k] * Covar.values[k] * max(self.EnvVar.TKE.values[k], 0)^0.5 /
            max(self.mixing_length[k], 1.0e-3) * c_d
        )
    end
    return
end

function update_covariance_ED(
    self::EDMF_PrognosticTKE,
    GMV::GridMeanVariables,
    Case::CasesBase,
    TS::TimeStepping,
    GmvVar1::VariablePrognostic,
    GmvVar2::VariablePrognostic,
    GmvCovar::VariableDiagnostic,
    Covar::EnvironmentVariable_2m,
    EnvVar1::EnvironmentVariable,
    EnvVar2::EnvironmentVariable,
    UpdVar1::UpdraftVariable,
    UpdVar2::UpdraftVariable,
)

    grid = get_grid(self)
    param_set = parameter_set(self)
    c_d = CPEDMF.c_d(param_set)
    kc_surf = kc_surface(grid)
    kf_surf = kf_surface(grid)
    kc_toa = kc_top_of_atmos(grid)
    dzi = grid.dzi
    dti = TS.dti
    Ref = reference_state(self)
    alpha0LL = Ref.alpha0_half[kc_surf]
    zLL = grid.z_half[kc_surf]
    a = center_field(grid)
    b = center_field(grid)
    c = center_field(grid)
    x = center_field(grid)
    ae = 1 .- self.UpdVar.Area.bulkvalues
    ae_old = 1 .- up_sum(self.UpdVar.Area.old)
    rho_ae_K_m = face_field(grid)
    w_en_c = center_field(grid)
    D_env = 0.0
    KM = diffusivity_m(self).values
    KH = diffusivity_h(self).values
    is_tke = Covar.name == "tke"

    aeK = is_tke ? ae .* KM : ae .* KH
    aeK_bcs = (; bottom = SetValue(aeK[kc_surf]), top = SetValue(aeK[kc_toa]))

    @inbounds for k in real_face_indices(grid)
        rho_ae_K_m[k] = interpc2f(aeK, grid, k; aeK_bcs...) * Ref.rho0[k]
    end

    @inbounds for k in real_center_indices(grid)
        w_en_c[k] = interpf2c(self.EnvVar.W.values, grid, k)
    end

    Covar_surf = Covar.values[kc_surf]

    @inbounds for k in real_center_indices(grid)
        D_env = 0.0

        @inbounds for i in xrange(self.n_updrafts)
            if self.UpdVar.Area.values[i, k] > self.minimum_area
                turb_entr = self.frac_turb_entr[i, k]
                R_up = self.pressure_plume_spacing[i]
                w_up_c = interpf2c(self.UpdVar.W.values, grid, k, i)
                D_env += Ref.rho0_half[k] * self.UpdVar.Area.values[i, k] * w_up_c * (self.entr_sc[i, k] + turb_entr)
            else
                D_env = 0.0
            end
        end

        # TODO: this tridiagonal matrix needs to be re-verified, as it's been pragmatically
        #       modified to not depend on ghost points, and these changes have not been
        #       carefully verified.
        if is_surface_center(grid, k)
            a[k] = 0.0
            b[k] = 1.0
            c[k] = 0.0
            x[k] = Covar_surf
        else
            a[k] = (-rho_ae_K_m[k] * dzi * dzi)
            b[k] = (
                Ref.rho0_half[k] * ae[k] * dti - Ref.rho0_half[k] * ae[k] * w_en_c[k] * dzi +
                rho_ae_K_m[k + 1] * dzi * dzi +
                rho_ae_K_m[k] * dzi * dzi +
                D_env +
                Ref.rho0_half[k] * ae[k] * c_d * sqrt(max(self.EnvVar.TKE.values[k], 0)) /
                max(self.mixing_length[k], 1)
            )
            x[k] = (
                Ref.rho0_half[k] * ae_old[k] * Covar.values[k] * dti +
                Covar.press[k] +
                Covar.buoy[k] +
                Covar.shear[k] +
                Covar.entr_gain[k] +
                Covar.rain_src[k]
            )
            if is_toa_center(grid, k)
                c[k] = 0.0
            else
                c[k] = (Ref.rho0_half[k + 1] * ae[k + 1] * w_en_c[k + 1] * dzi - rho_ae_K_m[k + 1] * dzi * dzi)
            end
        end
    end

    cinterior = real_center_indices(grid)
    x[cinterior] .= tridiag_solve(x[cinterior], a[cinterior], b[cinterior], c[cinterior])

    @inbounds for k in real_center_indices(grid)
        if Covar.name == "thetal_qt_covar"
            Covar.values[k] = max(x[k], -sqrt(self.EnvVar.Hvar.values[k] * self.EnvVar.QTvar.values[k]))
            Covar.values[k] = min(x[k], sqrt(self.EnvVar.Hvar.values[k] * self.EnvVar.QTvar.values[k]))
        else
            Covar.values[k] = max(x[k], 0.0)
        end
    end

    get_GMV_CoVar(
        self,
        self.UpdVar.Area,
        UpdVar1,
        UpdVar2,
        EnvVar1,
        EnvVar2,
        Covar,
        GmvVar1.values,
        GmvVar2.values,
        GmvCovar.values,
    )

    return
end

function GMV_third_m(
    self::EDMF_PrognosticTKE,
    Gmv_third_m::VariableDiagnostic,
    env_covar::EnvironmentVariable_2m,
    env_mean::EnvironmentVariable,
    upd_mean::UpdraftVariable,
)

    grid = get_grid(self)
    ae = 1 .- self.UpdVar.Area.bulkvalues
    au = self.UpdVar.Area.values
    is_tke = env_covar.name == "tke"

    @inbounds for k in real_center_indices(grid)
        mean_en = is_tke ? interpf2c(env_mean.values, grid, k) : env_mean.values[k]
        GMVv_ = ae[k] * mean_en
        @inbounds for i in xrange(self.n_updrafts)
            mean_up = is_tke ? interpf2c(upd_mean.values, grid, k, i) : upd_mean.values[i, k]
            GMVv_ += au[i, k] * mean_up
        end

        # TODO: report bug: i used outside of scope.
        # This is only valid (assuming correct) for 1
        # updraft.
        i_last = last(xrange(self.n_updrafts))
        if is_tke
            w_bcs = (; bottom = SetValue(0), top = SetValue(0))
            w_en_dual = dual_faces(self.EnvVar.W.values, grid, k)
            ∇w_en = ∇f2c(w_en_dual, grid, k; w_bcs...)
            Envcov_ = -self.horiz_K_eddy[i_last, k] * ∇w_en
        else
            Envcov_ = env_covar.values[k]
        end

        Upd_cubed = 0.0
        GMVcov_ = ae[k] * (Envcov_ + (mean_en - GMVv_)^2)
        @inbounds for i in xrange(self.n_updrafts)
            mean_up = is_tke ? interpf2c(upd_mean.values, grid, k, i) : upd_mean.values[i, k]
            GMVcov_ += au[i, k] * (mean_up - GMVv_)^2
            Upd_cubed += au[i, k] * mean_up^3
        end

        if is_surface_center(grid, k)
            Gmv_third_m.values[k] = 0.0 # this is here as first value is biased with BC area fraction
        else
            Gmv_third_m.values[k] =
                Upd_cubed + ae[k] * (mean_en^3 + 3 * mean_en * Envcov_) - GMVv_^3 - 3 * GMVcov_ * GMVv_
        end
    end
    return
end


# Update the diagnosis of the inversion height, using the maximum temperature gradient method
function update_inversion(self::EDMF_PrognosticTKE, GMV::GridMeanVariables, option)
    grid = self.Gr
    theta_rho = center_field(grid)
    ∇θ_liq_max = 0.0
    kc_surf = kc_surface(grid)
    param_set = parameter_set(GMV)

    @inbounds for k in real_center_indices(grid)
        qv = GMV.QT.values[k] - GMV.QL.values[k]
        ts = TD.PhaseEquil_pθq(param_set, self.Ref.p0_half[k], GMV.H.values[k], GMV.QT.values[k])
        theta_rho[k] = TD.virtual_pottemp(ts)
    end


    if option == "theta_rho"
        @inbounds for k in real_center_indices(grid)
            if theta_rho[k] > theta_rho[kc_surf]
                self.zi = grid.z_half[k]
                break
            end
        end
    elseif option == "thetal_maxgrad"

        @inbounds for k in real_center_indices(grid)
            ∇θ_liq_cut = ccut_downwind(GMV.H.values, grid, k)
            ∇θ_liq = c∇_downwind(∇θ_liq_cut, grid, k; bottom = FreeBoundary(), top = SetGradient(0))
            if ∇θ_liq > ∇θ_liq_max
                ∇θ_liq_max = ∇θ_liq
                self.zi = grid.z[k]
            end
        end
    elseif option == "critical_Ri"
        self.zi = get_inversion(param_set, theta_rho, GMV.U.values, GMV.V.values, grid, Ri_bulk_crit(self))

    else
        error("INVERSION HEIGHT OPTION NOT RECOGNIZED")
    end

    return
end
