
include("rrtmgp_model.jl")

update_radiation(self::TC.RadiationBase, grid, state, t::Real, param_set) = nothing
initialize(self::TC.RadiationBase{TC.RadiationNone}, grid, state) = nothing

"""
see eq. 3 in Stevens et. al. 2005 DYCOMS paper
"""
function update_radiation(self::TC.RadiationBase{TC.RadiationDYCOMS_RF01}, grid, state, t::Real, param_set)
    cp_d = CPP.cp_d(param_set)
    aux_gm = TC.center_aux_grid_mean(state)
    aux_gm_f = TC.face_aux_grid_mean(state)
    prog_gm = TC.center_prog_grid_mean(state)
    q_tot_f = TC.face_aux_turbconv(state).ϕ_temporary
    ρ_f = aux_gm_f.ρ
    ρ_c = prog_gm.ρ
    # find zi (level of 8.0 g/kg isoline of qt)
    # TODO: report bug: zi and ρ_i are not initialized
    zi = 0
    ρ_i = 0
    kc_surf = TC.kc_surface(grid)
    q_tot_surf = aux_gm.q_tot[kc_surf]
    If = CCO.InterpolateC2F(; bottom = CCO.SetValue(q_tot_surf), top = CCO.Extrapolate())
    @. q_tot_f .= If(aux_gm.q_tot)
    @inbounds for k in TC.real_face_indices(grid)
        if (q_tot_f[k] < 8.0 / 1000)
            idx_zi = k
            # will be used at cell faces
            zi = grid.zf[k]
            ρ_i = ρ_f[k]
            break
        end
    end

    ρ_z = Dierckx.Spline1D(vec(grid.zc), vec(ρ_c); k = 1)
    q_liq_z = Dierckx.Spline1D(vec(grid.zc), vec(aux_gm.q_liq); k = 1)

    integrand(ρq_l, params, z) = params.κ * ρ_z(z) * q_liq_z(z)
    rintegrand(ρq_l, params, z) = -integrand(ρq_l, params, z)

    z_span = (grid.zmin, grid.zmax)
    rz_span = (grid.zmax, grid.zmin)
    params = (; κ = self.kappa)

    Δz = TC.get_Δz(prog_gm.ρ)[1]
    rprob = ODE.ODEProblem(rintegrand, 0.0, rz_span, params; dt = Δz)
    rsol = ODE.solve(rprob, ODE.Tsit5(), reltol = 1e-12, abstol = 1e-12)
    q_0 = rsol.(vec(grid.zf))

    prob = ODE.ODEProblem(integrand, 0.0, z_span, params; dt = Δz)
    sol = ODE.solve(prob, ODE.Tsit5(), reltol = 1e-12, abstol = 1e-12)
    q_1 = sol.(vec(grid.zf))
    parent(aux_gm_f.f_rad) .= self.F0 .* exp.(-q_0)
    parent(aux_gm_f.f_rad) .+= self.F1 .* exp.(-q_1)

    # cooling in free troposphere
    @inbounds for k in TC.real_face_indices(grid)
        if grid.zf[k] > zi
            cbrt_z = cbrt(grid.zf[k] - zi)
            aux_gm_f.f_rad[k] += ρ_i * cp_d * self.divergence * self.alpha_z * (cbrt_z^4 / 4 + zi * cbrt_z)
        end
    end

    ∇c = CCO.DivergenceF2C()
    wvec = CC.Geometry.WVector
    @. aux_gm.dTdt_rad = -∇c(wvec(aux_gm_f.f_rad)) / ρ_c / cp_d

    return
end

function initialize(self::TC.RadiationBase{TC.RadiationLES}, grid, state, LESDat::TC.LESData)
    # load from LES
    aux_gm = TC.center_aux_grid_mean(state)
    dTdt = NC.Dataset(LESDat.les_filename, "r") do data
        imin = LESDat.imin
        imax = LESDat.imax

        # interpolate here
        zc_les = Array(TC.get_nc_data(data, "zc"))
        meandata = TC.mean_nc_data(data, "profiles", "dtdt_rad", imin, imax)
        pyinterp(grid.zc, zc_les, meandata)
    end
    @inbounds for k in TC.real_center_indices(grid)
        aux_gm.dTdt_rad[k] = dTdt[k]
    end
    return
end


function initialize_rrtmgp(grid, state, param_set)
    FT = eltype(grid)
    prog_gm = TC.center_prog_grid_mean(state)
    aux_gm = TC.center_aux_grid_mean(state)
    ρ_c = prog_gm.ρ
    p_c = aux_gm.p
    ds_input = rrtmgp_artifact("atmos_state", "clearsky_as.nc")
    nlay = ds_input.dim["layer"]
    nsite = ds_input.dim["site"]
    nexpt = ds_input.dim["expt"]
    ncol = nsite * nexpt

    vmrs = map((
        # ("h2o", "water_vapor"),            # overwritten by vmr_h2o
        ("co2", "carbon_dioxide_GM"),
        # ("o3", "ozone"),                   # overwritten by vmr_o3
        ("n2o", "nitrous_oxide_GM"),
        ("co", "carbon_monoxide_GM"),
        ("ch4", "methane_GM"),
        ("o2", "oxygen_GM"),
        ("n2", "nitrogen_GM"),
        ("ccl4", "carbon_tetrachloride_GM"),
        ("cfc11", "cfc11_GM"),
        ("cfc12", "cfc12_GM"),
        ("cfc22", "hcfc22_GM"),
        ("hfc143a", "hfc143a_GM"),
        ("hfc125", "hfc125_GM"),
        ("hfc23", "hfc23_GM"),
        ("hfc32", "hfc32_GM"),
        ("hfc134a", "hfc134a_GM"),
        ("cf4", "cf4_GM"),
        # ("no2", nothing),                  # not available in input dataset
    )) do (lookup_gas_name, input_gas_name)
        (
            Symbol("volume_mixing_ratio_" * lookup_gas_name),
            get_var(input_gas_name, ds_input, nsite, nexpt, ncol)'[1] .* parse(FT, ds_input[input_gas_name].attrib["units"]),
        )
    end

    # get model shape from model density
    volume_mixing_ratio_h2o = vec(p_c)
    p_c = vec(p_c)
    temperature = vec(ρ_c)
    z = vec(grid.zf)

    rrtmgp_model = RRTMGPModel(
        param_set,
        z;
        level_computation = :average,
        use_ideal_coefs_for_bottom_level = false,
        add_isothermal_boundary_layer = true,
        surface_emissivity = get_var("surface_emissivity", ds_input, nsite, nexpt, ncol)'[1],
        solar_zenith_angle = FT(π) / 2 - eps(FT),
        weighted_irradiance = FT(CP.Planet.tot_solar_irrad(param_set)),
        dir_sw_surface_albedo = get_var("surface_albedo", ds_input, nsite, nexpt, ncol)'[1],
        dif_sw_surface_albedo = get_var("surface_albedo", ds_input, nsite, nexpt, ncol)'[1],
        pressure = vec(p_c),
        temperature = vec(p_c),
        surface_temperature = get_var("surface_temperature", ds_input, nsite, nexpt, ncol)[1],
        latitude = get_var("lat", ds_input, nsite, nexpt, ncol)[1],
        volume_mixing_ratio_h2o = vec(p_c),
        volume_mixing_ratio_o3 = get_var("ozone", ds_input, nsite, nexpt, ncol)[1],
        vmrs...,
        volume_mixing_ratio_no2 = 0,
    )
    return rrtmgp_model
end

function update_radiation(self::TC.RadiationBase{TC.RadiationRRTMGP}, grid, state, param_set)

    cp_d = CPP.cp_d(param_set)
    aux_gm = TC.center_aux_grid_mean(state)
    prog_gm = TC.center_prog_grid_mean(state)
    aux_gm_f = TC.face_aux_grid_mean(state)
    ρ_c = prog_gm.ρ
    p_c = aux_gm.p

    UnPack.@unpack rrtmgp_model = params

    ϵ_d = CPP.molmass_ratio(param_set)

    rrtmgp_model.temperature .= vec(aux_gm.T)
    rrtmgp_model.pressure .= vec(p_c)
    rrtmgp_model.volume_mixing_ratio_h2o .= vec(@. ϵ_d * aux_gm.q_tot / (1 - aux_gm.q_tot))
    rrtmgp_flux = vec(grid.zf)
    vec(rrtmgp_flux) .= compute_fluxes!(rrtmgp_model)
    @inbounds for k in TC.real_face_indices(grid)
        aux_gm_f.f_rad[k] = rrtmgp_flux[k]
    end
    ∇c = CCO.DivergenceF2C()
    wvec = CC.Geometry.WVector
    @. aux_gm.dTdt_rad = -∇c(wvec(aux_gm_f.f_rad)) / ρ_c / cp_d
    return
end

function initialize(self::TC.RadiationBase{TC.RadiationTRMM_LBA}, grid, state)
    aux_gm = TC.center_aux_grid_mean(state)
    rad = APL.TRMM_LBA_radiation(eltype(grid))
    @inbounds for k in real_center_indices(grid)
        aux_gm.dTdt_rad[k] = rad(0, grid.zc[k].z)
    end
    return nothing
end

function update_radiation(self::TC.RadiationBase{TC.RadiationTRMM_LBA}, grid, state, t::Real, param_set)
    aux_gm = TC.center_aux_grid_mean(state)
    rad = APL.TRMM_LBA_radiation(eltype(grid))
    @inbounds for k in real_center_indices(grid)
        aux_gm.dTdt_rad[k] = rad(t, grid.zc[k].z)
    end
    return nothing
end