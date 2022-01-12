"""
    nh_pressure_buoy(param_set, a_up, b_up, ρ0, asp_ratio, bcs)

Returns the value of perturbation pressure gradient
for updraft i following [He2020](@cite), given:

 - `a_up`: updraft area
 - `b_up`: updraft buoyancy
 - `ρ0`: reference density
 - `asp_ratio`: the specific aspect ratio of the updraft
 - `bcs`: a `NamedTuple` of BCs with updraft area fraction and buoyancy entries
"""
function nh_pressure_buoy(::Type{FT}, param_set::APS, a_up, b_up, ρ0, bcs) where {FT <: Real}
    Ifb = CCO.InterpolateC2F(; bcs.b_up...)
    Ifa = CCO.InterpolateC2F(; bcs.a_up...)

    α_b::FT = CPEDMF.α_b(param_set)
    # Note: Independence of aspect ratio hardcoded in implementation.
    α₂_asp_ratio² = FT(0)

    return @. Int(Ifa(a_up) > 0) * -α_b / (1 + α₂_asp_ratio²) * ρ0 * Ifa(a_up) * Ifb(b_up)
end

"""
    nh_pressure_adv(param_set, a_up, ρ0, w_up, bcs)

Returns the value of perturbation pressure gradient
for updraft i following [He2020](@cite), given:

 - `a_up`: updraft area
 - `ρ0`: reference density
 - `w_up`: updraft vertical velocity
 - `bcs`: a `NamedTuple` of BCs with updraft velocity and area fraction entries
"""
function nh_pressure_adv(::Type{FT}, param_set::APS, a_up, ρ0, w_up, bcs) where {FT <: Real}

    Ifa = CCO.InterpolateC2F(; bcs.a_up...)
    Ifc = CCO.InterpolateF2C()
    ∇ = CCO.DivergenceC2F(; bcs.w_up...)
    α_a::FT = CPEDMF.α_a(param_set)
    wvec = CC.Geometry.WVector

    return @. Int(Ifa(a_up) > 0) * ρ0 * Ifa(a_up) * α_a * w_up * ∇(wvec(Ifc(w_up)))
end;

"""
    nh_pressure_drag(param_set, H_up, a_up, ρ0, w_up, w_en, bcs)

Returns the value of perturbation pressure gradient
for updraft i following [He2020](@cite), given:

 - `H_up`: the updraft scale height
 - `a_up`: updraft area
 - `ρ0`: reference density
 - `w_up`: updraft vertical velocity
 - `w_en`: environment vertical velocity
 - `bcs`: a `NamedTuple` of BCs with an updraft area fraction entry
"""
function nh_pressure_drag(param_set::APS, H_up::FT, a_up, ρ0, w_up, w_en, bcs) where {FT <: Real}

    Ifa = CCO.InterpolateC2F(; bcs.a_up...)
    α_d::FT = CPEDMF.α_d(param_set)

    # drag as w_dif and account for downdrafts
    return @. Int(Ifa(a_up) > 0) * -1 * ρ0 * Ifa(a_up) * α_d * (w_up - w_en) * abs(w_up - w_en) / H_up
end;
