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

## Input assumptions

When some inputs are unavailable, use explicit, recorded assumptions. The
library does not fill in defaults automatically.

| Field | Suggested assumption |
|---|---|
| `pressure_hpa` | Prefer an estimate from site elevation. `1013.25` hPa is a sea-level screening assumption. |
| `wind_height_m` | Use `10` only when the source specifies wind measured at 10 m; otherwise use instrument metadata. |
| `vertical_temperature_difference_c` | `1` assumes a nighttime inversion. Only negative versus nonnegative matters. |
| `urban` | Use `0` for rural or `1` for urban. If unknown, calculate both and retain the higher WBGT for screening. |
| `averaging_minutes` | Use the source averaging interval; `0` is appropriate only for instantaneous or already centered observations. |

Air temperature, humidity, wind speed, and daytime solar radiation have no
general fallback. See the
[input guide](https://github.com/zyf0717/lwbgt/blob/main/docs/INPUTS.md) for units,
timestamp conventions, and when these assumptions affect the calculation.

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

## License

This Julia wrapper is licensed under [Apache-2.0](LICENSE).
