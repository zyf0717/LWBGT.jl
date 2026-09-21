module LWBGT

using Libdl

export Input, Result, calculate, calculate_batch, esat

include("types.jl")
include("ffi.jl")

function __init__()
    _library_handle[] = C_NULL
    _batch_pointer[] = C_NULL
    _esat_pointer[] = C_NULL
end

end
