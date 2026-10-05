# Linux integration check: Julia and independent C scalar probes use the same JLL.
# Usage: julia --project=. test/corpus.jl /path/to/pinned/lwbgt
using LWBGT
using Test
using lwbgt_jll

function read_inputs(path)
    map(readlines(path)[2:end]) do line
        row = split(line, ',')
        # Native CSV places urban last; the ABI places it before the doubles.
        Input(parse.(Int32, row[3:9])..., parse(Int32, row[19]),
              parse.(Float64, row[10:18])...)
    end
end

output_bits(result) = ntuple(i -> reinterpret(UInt32, getfield(result, i + 1)), 5)

function check_wbgt(probe, cases, expected_count)
    inputs = read_inputs(cases)
    expected = split.(readlines(`$probe $cases`)[2:end], ',')
    results = calculate_batch(inputs)
    @test length(inputs) == length(expected) == length(results) == expected_count
    for (input, result, row) in zip(inputs, results, expected)
        @test result.status == parse(Int32, row[2])
        @test output_bits(result) == Tuple(parse.(UInt32, row[3:7]; base=16))
        @test reinterpret(UInt32, esat(input.air_temperature_c + 273.15)) ==
              parse(UInt32, row[8]; base=16)
        scalar = calculate(input)
        @test scalar.status == result.status
        @test output_bits(scalar) == output_bits(result)
    end
end

length(ARGS) == 1 || error("usage: julia --project=. test/corpus.jl /path/to/lwbgt")
native = abspath(only(ARGS))
@info "Kernel alignment" jll_version=pkgversion(lwbgt_jll) library=liblwbgt

mktempdir() do directory
    cases = joinpath(directory, "cases.csv")
    weather = joinpath(directory, "weather.csv")
    saturation = joinpath(directory, "esat.csv")
    generator = joinpath(native, "tests", "generate_cases.py")
    run(`python3 $generator $cases --weather-output $weather --esat-output $saturation`)

    # Compile only the consumers, never a replacement kernel. Use the shipped
    # header and an absolute library path with rpath for the probe subprocesses.
    include_dir = joinpath(lwbgt_jll.artifact_dir, "include")
    library_dir = dirname(liblwbgt)
    compiler = get(ENV, "CC", "cc")
    for name in ("probe", "esat_probe")
        source = joinpath(native, "tests", "$name.c")
        executable = joinpath(directory, name)
        run(`$compiler -std=c11 -I$include_dir $source $liblwbgt -Wl,-rpath,$library_dir -o $executable`)
    end

    @testset "WBGT corpus" begin
        check_wbgt(joinpath(directory, "probe"), cases, 35976)
    end
    @testset "invalid weather corpus" begin
        check_wbgt(joinpath(directory, "probe"), weather, 64)
    end
    @testset "water/ice corpus" begin
        inputs = split.(readlines(saturation)[2:end], ',')
        probe = joinpath(directory, "esat_probe")
        expected = split.(readlines(`$probe $saturation`)[2:end], ',')
        @test length(inputs) == length(expected) == 1682
        for (row, reference) in zip(inputs, expected)
            result = esat(parse(Float64, row[1]), parse(Int, row[2]))
            @test reinterpret(UInt32, result) == parse(UInt32, reference[2]; base=16)
        end
    end
end
