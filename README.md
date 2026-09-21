# LWBGT.jl

Thin Julia binding to the stable FFI v1 interface of
[`lwbgt`](https://github.com/zyf0717/lwbgt), the reference-compatible
Liljegren outdoor wet bulb globe temperature kernel.

The API follows the native and Python interfaces: immutable `Input` and
`Result` records map field-for-field to the C ABI, `calculate` handles one
record, `calculate_batch` submits an entire collection in one native call, and
`esat` exposes saturation vapour pressure. Field names encode their units. The
package does not validate, clamp, convert, or replace solver failures.

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

## Native library

Until `lwbgt_jll` is available, install or build the `lwbgt` shared library and
either place it on the platform library search path or set `LWBGT_LIBRARY` to
its absolute path before the first calculation:

```sh
export LWBGT_LIBRARY=/absolute/path/to/liblwbgt.so
```

The equivalent filenames are `liblwbgt.dylib` on macOS and `lwbgt.dll` on
Windows. Library loading is lazy, so constructing records and calculating an
empty batch do not require the shared library.

The native batch call is serial. Independent Julia tasks may call the package
concurrently because the kernel has no mutable calculation state and each call
uses separate buffers.
