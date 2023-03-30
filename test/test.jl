using Test
using LinearAlgebra
using Plots
using Random
using SatelliteDynamics
include("../src/GNCTestServer.jl")

@testset "basic single variable integration" begin
    idx = x -> x
    @test GNCTestServer.rk4(0.0, 0.0, 0.1, (x, t) -> 2 * x + 1) ≈ 0.11 atol = 0.01
    @test GNCTestServer.rk4(0.0, 3.0, 0.1, (x, t) -> sin(x)) ≈ 0.009142653672834007 atol = 0.01
end;

function no_control(measure, t)
    return zero(GNCTestServer.Control)
end

@testset "Distance from center of earth" begin
    earth_radius = 6378.1 * 1000
    function log_init(state)
        return [norm(state.position) - earth_radius]
    end
    function log_step(hist, state)
        point = norm(state.position) - earth_radius
        push!(hist, point)
    end
    (data, time) = GNCTestServer.simulate(no_control, max_iterations=10000, log_init=log_init, log_step=log_step, dt=10.0)
    data /= 1000
    display(plot(time, data, title="Distance from earth", xlabel="Time (s)", ylabel="Distance from earth (km)", labels="r"))
end

function energy(state; J=[0.3 0 0; 0 0.3 0; 0 0 0.3], μ=3.9860044188e14)
    r = state.position
    ω = state.angular_velocity
    v = state.velocity

    KE = 0.5 * norm(v)^2
    PE = -μ / norm(r)
    Eᵣ = 0.5 * ω' * J * ω
    return Eᵣ + KE + PE
end

@testset "Conservation of energy" begin
    function log_init(state)
        return [energy(state)]
    end
    function log_step(hist, state)
        point = energy(state)
        push!(hist, point)
    end
    (data, time) = GNCTestServer.simulate(no_control, max_iterations=100000, log_init=log_init, log_step=log_step, dt=0.5)
    display(plot(time, data, title="Energy", xlabel="Time (s)", ylabel="Energy", labels="E"))
end

@testset "detumbling" begin
    Random.seed!(1234)
    function control_law(measurement, t)
        ω = measurement[1].angular_velocity
        b = measurement[2].b

        b̂ = b / norm(b)
        k = 7e-4
        M = -k * (I(3) - b̂ * b̂') * ω
        m = 1 / (dot(b, b)) * cross(b, M)
        return GNCTestServer.Control(
            m
        )
    end

    (data, time) = GNCTestServer.simulate(control_law, max_iterations=10000)
    display(plot(time, data, title="DeTumbling", xlabel="Time (s)", ylabel="Angular Velocity (rad/s)", labels=["ω1" "ω2" "ω3" "ω"]))
end

@testset "io" begin
    Random.seed!(1234)
    (data, time) = GNCTestServer.simulate(`sh runfakesat.sh`, max_iterations=2000)
    display(plot(time, data, title="Socket DeTumbling", xlabel="Time (s)", ylabel="Angular Velocity (rad/s)", labels=["ω1" "ω2" "ω3" "ω"]))
end
