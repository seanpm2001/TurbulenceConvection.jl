"""
Computes the qr advection (down) tendency
"""
function compute_precipitation_advection_tendencies(grid, state, gm, TS::TimeStepping)
    param_set = parameter_set(gm)
    Δz = grid.Δz
    Δt = TS.dt
    CFL_limit = 0.5

    ρ_0_c = center_ref_state(state).ρ0
    tendencies_pr = center_tendencies_precipitation(state)
    prog_pr = center_prog_precipitation(state)
    aux_tc = center_aux_turbconv(state)

    # helper to calculate the rain velocity
    # TODO: assuming gm.W = 0
    # TODO: verify translation
    term_vel_rain = aux_tc.term_vel_rain
    term_vel_snow = aux_tc.term_vel_snow

    @inbounds for k in real_center_indices(grid)
        term_vel_rain[k] = CM1.terminal_velocity(param_set, rain_type, ρ_0_c[k], prog_pr.q_rai[k])
        term_vel_snow[k] = CM1.terminal_velocity(param_set, snow_type, ρ_0_c[k], prog_pr.q_sno[k])
    end

    @inbounds for k in reverse(real_center_indices(grid))
        # check stability criterion
        CFL_out_rain = Δt / Δz * term_vel_rain[k]
        CFL_out_snow = Δt / Δz * term_vel_snow[k]
        if is_toa_center(grid, k)
            CFL_in_rain = 0.0
            CFL_in_snow = 0.0
        else
            CFL_in_rain = Δt / Δz * term_vel_rain[k + 1]
            CFL_in_snow = Δt / Δz * term_vel_snow[k + 1]
        end
        if max(CFL_in_rain, CFL_in_snow, CFL_out_rain, CFL_out_snow) > CFL_limit
            error("Time step is too large for rain fall velocity!")
        end

        ρ_0_cut = ccut_downwind(ρ_0_c, grid, k)

        QR_cut = ccut_downwind(prog_pr.q_rai, grid, k)
        QS_cut = ccut_downwind(prog_pr.q_sno, grid, k)

        w_cut_rain = ccut_downwind(term_vel_rain, grid, k)
        w_cut_snow = ccut_downwind(term_vel_snow, grid, k)

        ρQRw_cut = ρ_0_cut .* QR_cut .* w_cut_rain
        ρQSw_cut = ρ_0_cut .* QS_cut .* w_cut_snow

        ∇ρQRw = c∇_downwind(ρQRw_cut, grid, k; bottom = FreeBoundary(), top = SetValue(0))
        ∇ρQSw = c∇_downwind(ρQSw_cut, grid, k; bottom = FreeBoundary(), top = SetValue(0))

        ρ_0_c_k = ρ_0_c[k]

        # TODO - some positivity limiters are needed
        aux_tc.qr_tendency_advection[k] = ∇ρQRw / ρ_0_c_k
        aux_tc.qs_tendency_advection[k] = ∇ρQSw / ρ_0_c_k

        tendencies_pr.q_rai[k] += aux_tc.qr_tendency_advection[k]
        tendencies_pr.q_sno[k] += aux_tc.qs_tendency_advection[k]
    end
    return
end

"""
Computes the tendencies to θ_liq_ice, qt and qr due to rain evaporation
"""
function compute_precipitation_sink_tendencies(grid, state, gm, TS::TimeStepping)
    param_set = parameter_set(gm)
    Δt = TS.dt
    p0_c = center_ref_state(state).p0
    ρ0_c = center_ref_state(state).ρ0
    aux_gm = center_aux_grid_mean(state)
    aux_tc = center_aux_turbconv(state)
    prog_gm = center_prog_grid_mean(state)
    prog_pr = center_prog_precipitation(state)
    tendencies_pr = center_tendencies_precipitation(state)

    @inbounds for k in real_center_indices(grid)
        q_tot_gm = prog_gm.q_tot[k]
        T_gm = aux_gm.T[k]
        # When we fuse loops, this should hopefully disappear
        ts = TD.PhaseEquil_pTq(param_set, p0_c[k], T_gm, q_tot_gm)
        q = TD.PhasePartition(ts)

        # TODO - move limiters elsewhere
        rain_evap =
            -min(
                prog_pr.q_rai[k] / Δt,
                -CM1.evaporation_sublimation(param_set, rain_type, q, prog_pr.q_rai[k], ρ0_c[k], T_gm),
            )

        aux_tc.qr_tendency_evap[k] = rain_evap
        aux_tc.qs_tendency_melt[k] = 0.0
        aux_tc.qs_tendency_dep_sub[k] = 0.0

        aux_tc.qt_tendency_precip_sinks[k] = -rain_evap
        aux_tc.θ_liq_ice_tendency_precip_sinks[k] = θ_liq_ice_helper(ts, -rain_evap)

        tendencies_pr.q_rai[k] += rain_evap
    end
    return
end