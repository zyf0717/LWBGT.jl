using LWBGT
using Test

const SINGAPORE = Input(
    year=2024,
    month=4,
    day=15,
    hour=14,
    minute=30,
    gmt_offset_hours=8,
    averaging_minutes=60,
    urban=1,
    latitude_deg_north=1.3521,
    longitude_deg_east=103.8198,
    solar_w_m2=742.0,
    pressure_hpa=1008.4,
    air_temperature_c=32.1,
    relative_humidity_percent=68.0,
    wind_speed_m_s=2.8,
    wind_height_m=10.0,
    vertical_temperature_difference_c=-0.4,
)

const SOLVER_FAILURE = Input(
    year=2024,
    month=3,
    day=20,
    hour=12,
    minute=0,
    gmt_offset_hours=0,
    averaging_minutes=0,
    urban=0,
    latitude_deg_north=0.0,
    longitude_deg_east=0.0,
    solar_w_m2=1000.0,
    pressure_hpa=300.0,
    air_temperature_c=60.0,
    relative_humidity_percent=100.0,
    wind_speed_m_s=0.129,
    wind_height_m=2.0,
    vertical_temperature_difference_c=0.0,
)

# Compare float bits so NaNs and signed zeros retain their native semantics.
output_bits(result) = ntuple(i -> reinterpret(UInt32, getfield(result, i + 1)), 5)
with_input(input; changes...) = Input(;
    NamedTuple{fieldnames(Input)}(ntuple(i -> getfield(input, i), fieldcount(Input)))...,
    changes...,
)

@testset "ABI records" begin
    @test isbitstype(Input)
    @test isbitstype(Result)
    @test sizeof(Input) == 104
    @test sizeof(Result) == 24
    @test SINGAPORE.year === Int32(2024)
    @test SINGAPORE.solar_w_m2 === 742.0
    @test_throws ErrorException setproperty!(SINGAPORE, :year, Int32(2023))
end

@testset "empty batch" begin
    @test calculate_batch(Input[]) == Result[]
    @test calculate_batch(()) == Result[]
end

@testset "native FFI" begin
    result = calculate(SINGAPORE)
    @test result.status == 0
    # Golden values allow small differences between platform math libraries.
    @test result.wbgt_c ≈ reinterpret(Float32, 0x42020259) rtol=4eps(Float32)

    batch = calculate_batch((SINGAPORE, SOLVER_FAILURE))
    @test batch[1] == result
    @test batch[2].status == -1
    @test batch[2].globe_temperature_c == -9999.0f0
    @test calculate([SINGAPORE]) == [result]

    @test esat(273.15) ≈ reinterpret(Float32, 0x40c45e95) rtol=4eps(Float32)
    @test esat(273.15, 1) ≈ reinterpret(Float32, 0x40c459a5) rtol=4eps(Float32)
    @test esat(273.15; phase=1) == esat(273.15, 1)
end

@testset "batch contract" begin
    night = with_input(SINGAPORE; hour=2, solar_w_m2=0.0)
    inputs = [night, SINGAPORE, SOLVER_FAILURE]
    before = copy(inputs)
    expected = calculate.(inputs)
    @test calculate_batch(inputs) == expected
    @test calculate_batch(input for input in inputs) == expected
    @test calculate(view(inputs, 1:2:3)) == expected[1:2:3]
    @test inputs == before

    at_two_metres = with_input(SINGAPORE; wind_height_m=2.0)
    @test calculate(at_two_metres).estimated_wind_speed_m_s === Float32(at_two_metres.wind_speed_m_s)
end

@testset "rejected solar inputs" begin
    for changes in ((year=1949,), (year=2050,), (month=13,),
                    (latitude_deg_north=90.01,), (longitude_deg_east=180.01,))
        input = with_input(SINGAPORE; changes...)
        result = calculate(input)
        @test result.status == -1
        @test output_bits(result) == ntuple(_ -> reinterpret(UInt32, -9999.0f0), 5)
        @test calculate_batch([input]) == [result]
    end
end

@testset "non-finite weather" begin
    for field in (:solar_w_m2, :pressure_hpa, :air_temperature_c,
                  :relative_humidity_percent, :wind_speed_m_s, :wind_height_m,
                  :vertical_temperature_difference_c), value in (NaN, Inf, -Inf)
        input = with_input(SINGAPORE; field => value)
        scalar = calculate(input)
        batch = only(calculate_batch([input]))
        @test scalar.status == batch.status
        @test output_bits(scalar) == output_bits(batch)
    end
end

@testset "concurrent calls" begin
    inputs = [SINGAPORE, SOLVER_FAILURE]
    expected = calculate_batch(inputs)
    tasks = [Threads.@spawn(calculate_batch(inputs)) for _ in 1:16]
    @test all(==(expected), fetch.(tasks))
end
