import JSON
using ArgParse
import TurbulenceConvection

include("parameter_set.jl")
include("Cases.jl")
import .Cases

mutable struct Simulation1d
    grid
    ref_state
    GMV
    Case
    Turb
    TS
    Stats
end

function Simulation1d(namelist)
    TC = TurbulenceConvection
    param_set = create_parameter_set(namelist)
    grid = TC.Grid(namelist)
    ref_state = TC.ReferenceState(grid, param_set)
    GMV = TC.GridMeanVariables(namelist, grid, ref_state, param_set)

    case_type = Cases.get_case(namelist)
    Sur = TC.SurfaceBase(Cases.get_surface_type(case_type); grid, ref_state, namelist)
    Fo = TC.ForcingBase{Cases.get_forcing_type(case_type)}(; grid, ref_state)
    Rad = TC.RadiationBase{Cases.get_radiation_type(case_type)}(; grid, ref_state)

    Case = Cases.CasesBase(case_type, namelist, grid, ref_state, Sur, Fo, Rad)
    Turb = TC.EDMF_PrognosticTKE(namelist, grid, ref_state, param_set)
    TS = TC.TimeStepping(namelist)
    Stats = TC.NetCDFIO_Stats(namelist, grid)
    return Simulation1d(grid, ref_state, GMV, Case, Turb, TS, Stats)
end

function TurbulenceConvection.initialize(self::Simulation1d, namelist)
    TC = TurbulenceConvection
    Cases.initialize_reference(self.Case, self.grid, self.ref_state, self.Stats)
    Cases.initialize_profiles(self.Case, self.grid, self.GMV, self.ref_state)

    Cases.initialize_surface(self.Case, self.grid, self.ref_state)
    Cases.initialize_forcing(self.Case, self.grid, self.ref_state, self.GMV)
    Cases.initialize_radiation(self.Case, self.grid, self.ref_state, self.GMV)

    TC.initialize(self.Turb, self.Case, self.GMV, self.ref_state, self.TS)
    TC.initialize_io(self)
    TC.io(self)

    return
end

function run(self::Simulation1d)
    TC = TurbulenceConvection
    iter = 0
    TC.open_files(self.Stats) # #removeVarsHack
    while self.TS.t <= self.TS.t_max
        TC.update(self.Turb, self.GMV, self.Case, self.TS)
        TC.update(self.TS)

        if mod(iter, 100) == 0
            progress = self.TS.t / self.TS.t_max
            @show progress
        end
        if mod(self.TS.t, self.Stats.frequency) == 0
            # TODO: remove `vars` hack that avoids
            # https://github.com/Alexander-Barth/NCDatasets.jl/issues/135
            # opening/closing files every step should be okay. #removeVarsHack
            # TurbulenceConvection.io(self) # #removeVarsHack
            TC.write_simulation_time(self.Stats, self.TS.t) # #removeVarsHack
            TC.io(self.GMV, self.Stats) # #removeVarsHack
            TC.io(self.Case, self.Stats) # #removeVarsHack
            TC.io(self.Turb, self.Stats, self.TS) # #removeVarsHack
        end
        iter += 1
    end
    TC.close_files(self.Stats) # #removeVarsHack
    return
end

function TurbulenceConvection.initialize_io(self::Simulation1d)
    TC = TurbulenceConvection
    TC.initialize_io(self.GMV, self.Stats)
    TC.initialize_io(self.Case, self.Stats)
    TC.initialize_io(self.Turb, self.Stats)
    return
end

function TurbulenceConvection.io(self::Simulation1d)
    TC = TurbulenceConvection
    TC.open_files(self.Stats)
    TC.write_simulation_time(self.Stats, self.TS.t)
    TC.io(self.GMV, self.Stats)
    TC.io(self.Case, self.Stats)
    TC.io(self.Turb, self.Stats, self.TS)
    TC.close_files(self.Stats)
    return
end

function main(namelist; kwargs...)
    main1d(namelist; kwargs...)
end

function main1d(namelist; time_run = false)
    Simulation = Simulation1d(namelist)
    TurbulenceConvection.initialize(Simulation, namelist)
    if time_run
        @time run(Simulation)
    else
        run(Simulation)
    end
    println("The simulation has completed.")
    return Simulation.Stats.path_plus_file
end


function parse_commandline()
    s = ArgParseSettings(; description = "Run case input")

    @add_arg_table! s begin
        "case_name"
        help = "The case name"
        arg_type = String
        required = true
    end

    return parse_args(s)
end

if abspath(PROGRAM_FILE) == @__FILE__

    args = parse_commandline()
    case_name = args["case_name"]

    namelist = open("namelist_" * "$case_name.in", "r") do io
        JSON.parse(io; dicttype = Dict, inttype = Int64)
    end
    main(namelist)
end
