"""
    Input(; year, month, day, hour, minute, gmt_offset_hours,
          averaging_minutes, urban, latitude_deg_north,
          longitude_deg_east, solar_w_m2, pressure_hpa,
          air_temperature_c, relative_humidity_percent,
          wind_speed_m_s, wind_height_m,
          vertical_temperature_difference_c)

One input record for the lwbgt FFI v1 calculation. Field names encode the
required units. `month == 0` means that `day` is a day of year; `urban` is zero
for rural or one for urban wind scaling.

The record maps directly to `lwbgt_input_v1`. The wrapper does not validate,
clamp, or convert its values.
"""
Base.@kwdef struct Input
    year::Int32
    month::Int32
    day::Int32
    hour::Int32
    minute::Int32
    gmt_offset_hours::Int32
    averaging_minutes::Int32
    urban::Int32
    latitude_deg_north::Float64
    longitude_deg_east::Float64
    solar_w_m2::Float64
    pressure_hpa::Float64
    air_temperature_c::Float64
    relative_humidity_percent::Float64
    wind_speed_m_s::Float64
    wind_height_m::Float64
    vertical_temperature_difference_c::Float64
end

"""
    Result

One result from the lwbgt FFI v1 calculation. `status == 0` denotes success;
`status == -1` denotes solver non-convergence. A failed native calculation
retains the kernel's `-9999.0f0` output convention.
"""
struct Result
    status::Int32
    estimated_wind_speed_m_s::Float32
    globe_temperature_c::Float32
    natural_wet_bulb_c::Float32
    psychrometric_wet_bulb_c::Float32
    wbgt_c::Float32
end

const _INPUT_OFFSETS = (0, 4, 8, 12, 16, 20, 24, 28,
                        32, 40, 48, 56, 64, 72, 80, 88, 96)
const _RESULT_OFFSETS = (0, 4, 8, 12, 16, 20)

isbitstype(Input) || error("LWBGT.Input is not an isbits type")
isbitstype(Result) || error("LWBGT.Result is not an isbits type")
sizeof(Input) == 104 || error("LWBGT.Input layout is not 104 bytes")
sizeof(Result) == 24 || error("LWBGT.Result layout is not 24 bytes")
ntuple(index -> fieldoffset(Input, index), fieldcount(Input)) == _INPUT_OFFSETS ||
    error("LWBGT.Input field offsets do not match lwbgt_input_v1")
ntuple(index -> fieldoffset(Result, index), fieldcount(Result)) == _RESULT_OFFSETS ||
    error("LWBGT.Result field offsets do not match lwbgt_output_v1")
