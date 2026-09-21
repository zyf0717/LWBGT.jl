const _library_lock = ReentrantLock()
const _library_handle = Ref{Ptr{Cvoid}}(C_NULL)
const _batch_pointer = Ref{Ptr{Cvoid}}(C_NULL)
const _esat_pointer = Ref{Ptr{Cvoid}}(C_NULL)

function _library_candidates()
    if Sys.iswindows()
        return ["lwbgt.dll", "lwbgt"]
    elseif Sys.isapple()
        return ["liblwbgt.dylib", "lwbgt"]
    end
    return ["liblwbgt.so", "lwbgt"]
end

function _library_path()
    configured = get(ENV, "LWBGT_LIBRARY", "")
    if !isempty(configured)
        isfile(configured) ||
            throw(ErrorException("LWBGT_LIBRARY does not name a file: $configured"))
        return configured
    end

    found = Libdl.find_library(_library_candidates())
    isempty(found) && throw(ErrorException(
        "cannot find the lwbgt shared library; set LWBGT_LIBRARY to its path",
    ))
    return found
end

function _load_symbols!()
    _library_handle[] != C_NULL && return nothing

    lock(_library_lock) do
        _library_handle[] != C_NULL && return nothing
        path = _library_path()
        handle = try
            Libdl.dlopen(path)
        catch exception
            throw(ErrorException(
                "cannot load the lwbgt shared library at $path: " *
                sprint(showerror, exception),
            ))
        end

        batch = Libdl.dlsym_e(handle, :lwbgt_calc_batch_v1)
        saturation = Libdl.dlsym_e(handle, :esat)
        if batch == C_NULL || saturation == C_NULL
            Libdl.dlclose(handle)
            missing = batch == C_NULL ? "lwbgt_calc_batch_v1" : "esat"
            throw(ErrorException(
                "lwbgt shared library at $path does not export $missing",
            ))
        end

        _batch_pointer[] = batch
        _esat_pointer[] = saturation
        _library_handle[] = handle
        return nothing
    end
end

function _calculate_native!(inputs, outputs, count::Int)
    _load_symbols!()
    call_status = GC.@preserve inputs outputs begin
        ccall(
            _batch_pointer[],
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
empty result without loading the native library.
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
    _load_symbols!()
    return ccall(
        _esat_pointer[],
        Cfloat,
        (Cdouble, Cint),
        Float64(temperature_k),
        Cint(phase),
    )
end

"""
    esat(temperature_k[, phase=0]) -> Float32
    esat(temperature_k; phase=0) -> Float32

Return the native saturation vapour pressure for a temperature in kelvin.
`phase == 0` selects liquid water and `phase == 1` selects ice. Use Julia
broadcasting, `esat.(temperatures)`, for arrays.
"""
esat(temperature_k::Real, phase::Integer) = _esat(temperature_k, phase)
esat(temperature_k::Real; phase::Integer=0) = _esat(temperature_k, phase)
