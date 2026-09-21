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

if haskey(ENV, "LWBGT_LIBRARY")
    @testset "native FFI" begin
        result = calculate(SINGAPORE)
        @test result.status == 0
        @test reinterpret(UInt32, result.wbgt_c) == 0x42020259

        batch = calculate_batch((SINGAPORE, SOLVER_FAILURE))
        @test batch[1] == result
        @test batch[2].status == -1
        @test batch[2].globe_temperature_c == -9999.0f0
        @test calculate([SINGAPORE]) == [result]

        @test reinterpret(UInt32, esat(273.15)) == 0x40c45e95
        @test reinterpret(UInt32, esat(273.15, 1)) == 0x40c459a5
        @test esat(273.15; phase=1) == esat(273.15, 1)
    end
else
    @info "Skipping native integration tests; LWBGT_LIBRARY is not set"
end
