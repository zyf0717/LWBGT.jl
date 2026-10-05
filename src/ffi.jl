function _calculate_native!(inputs, outputs, count::Int)
    call_status = GC.@preserve inputs outputs begin
        ccall(
            (:lwbgt_calc_batch_v1, liblwbgt),
            Cint,
            (Ptr{Input}, Ptr{Result}, Csize_t),
            inputs,
            outputs,
            count,
        )
    end
    call_status == 0 || throw(ErrorException(
        "lwbgt_calc_batch_v1 rejected a valid wrapper call: $call_status",
    ))
    return outputs
end

"""
    calculate(input::Input) -> Result

Calculate one record through the versioned native FFI. Solver failure is
reported in `Result.status` and is not converted to an exception.
"""
function calculate(input::Input)
    native_input = Ref(input)
    native_output = Ref{Result}()
    _calculate_native!(native_input, native_output, 1)
    return native_output[]
end

"""
    calculate_batch(records) -> Vector{Result}

Calculate all `Input` records in one serial native batch call while preserving
their order. The input records are not mutated. An empty iterable returns an
empty result without calling the native kernel.
"""
function calculate_batch(records)
    inputs = collect(Input, records)
    isempty(inputs) && return Result[]
    outputs = Vector{Result}(undef, length(inputs))
    _calculate_native!(inputs, outputs, length(inputs))
    return outputs
end

calculate(inputs::AbstractVector{Input}) = calculate_batch(inputs)

function _esat(temperature_k::Real, phase::Integer)
    return ccall(
        (:esat, liblwbgt),
        Cfloat,
        (Cdouble, Cint),
        Float64(temperature_k),
        Cint(phase),
    )
end

"""
    esat(temperature_k[, phase=0]) -> Float32
    esat(temperature_k; phase=0) -> Float32

Return the native saturation vapour pressure in hPa for a temperature in kelvin.
`phase == 0` selects liquid water and `phase == 1` selects ice. Use Julia
broadcasting, `esat.(temperatures)`, for arrays.
"""
esat(temperature_k::Real, phase::Integer) = _esat(temperature_k, phase)
esat(temperature_k::Real; phase::Integer=0) = _esat(temperature_k, phase)
