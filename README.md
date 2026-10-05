# LWBGT.jl

Thin Julia binding to the stable FFI v1 interface of the C library
[`lwbgt`](https://github.com/zyf0717/lwbgt), the reference-compatible
Liljegren outdoor wet bulb globe temperature kernel.

The API follows the native and Python interfaces: immutable `Input` and
`Result` records map field-for-field to the C ABI, `calculate` handles one
record, `calculate_batch` submits an entire collection in one native call, and
`esat` exposes saturation vapour pressure. Field names encode their units. The
package does not validate, clamp, convert, or replace solver failures.

## Installation

Requires Julia 1.10 or later. Until the first General registration, install from
the repository:

```julia
using Pkg
Pkg.add(url="https://github.com/zyf0717/LWBGT.jl")
```

After registration, use `Pkg.add("LWBGT")`. The native library is installed
automatically through `lwbgt_jll` (v1.1.0 or later in the 1.x series); no C
compiler or manual library configuration is needed.

## Usage

```julia
using LWBGT

weather = Input(
    year=2024, month=4, day=15, hour=14, minute=30,
    gmt_offset_hours=8, averaging_minutes=60, urban=1,
    latitude_deg_north=1.3521, longitude_deg_east=103.8198,
    solar_w_m2=742.0, pressure_hpa=1008.4,
    air_temperature_c=32.1, relative_humidity_percent=68.0,
    wind_speed_m_s=2.8, wind_height_m=10.0,
    vertical_temperature_difference_c=-0.4,
)

result = calculate(weather)
@assert result.status == 0
println(result.wbgt_c)

results = calculate_batch([weather, weather])
println(esat(273.15; phase=0))
```

Temperatures in `Result` are in °C. `esat` accepts kelvin and returns hPa;
`phase=0` selects water and `phase=1` ice. `Result.status == 0` indicates success;
`-1` indicates a failed calculation. Failed fields retain the native
`-9999.0f0` sentinel; a solver failure can leave other fields finite.

The native batch call is serial. Independent Julia tasks may call the package
concurrently because the kernel has no mutable calculation state and each call
uses separate buffers.

## Testing

```sh
julia --threads=2 --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

CI tests Julia 1.10 on Linux and current stable Julia on Linux, macOS ARM64,
and Windows. Tests cover native loading, ABI layouts, scalar/batch consistency,
input preservation, rejected inputs, non-finite weather, and concurrent calls.

The Linux corpus check compares every output field and status with independent
C scalar probes linked to the **same installed JLL**: 35,976 WBGT cases, 64
invalid-weather cases, and 1,682 water/ice saturation-pressure cases. CI pins
the native fixtures to `b6c49eff1d34738ae40f1d6b51a62cc3a5d0e83d`, the source
revision used by `lwbgt_jll v1.1.0+0`. To reproduce with that native checkout,
Python 3.10+ and a C compiler on Linux:

```sh
julia --project=. test/corpus.jl /path/to/lwbgt
```

These checks require bitwise equality between callers of the same library.
Golden smoke tests allow small platform math-library differences. Comparison
with the retained original kernel is maintained in
[`lwbgt`](https://github.com/zyf0717/lwbgt/blob/main/tests/BASELINE.md).

## Releases

The Julia package and native kernel have independent versions. For v0.1.0:

1. Merge the release changes and require passing CI on `main`.
2. Confirm [Registrator](https://github.com/apps/juliaregistrator) is enabled
   for this repository, then comment `@JuliaRegistrator register` on the exact
   release commit. The version comes from `Project.toml`.
3. After the General registration merges, the TagBot workflow creates the tag
   and GitHub release. Keep workflow changes separate from the registered
   release commit: GitHub restricts TagBot's default token from tagging commits
   that modify workflows. See [TagBot troubleshooting](https://github.com/JuliaRegistries/TagBot#commits-that-modify-workflow-files).

## License

The Julia wrapper is licensed under [Apache-2.0](LICENSE). The native library
includes the modified Argonne kernel under its
[original terms](LicenseRef-UChicago-Argonne-WBGT-1.1.txt); see [NOTICE](NOTICE).

This product includes software produced by UChicago Argonne, LLC
under Contract No. DE-AC02-06CH11357 with the Department of Energy.
