module LWBGT

using lwbgt_jll: liblwbgt

export Input, Result, calculate, calculate_batch, esat

include("types.jl")
include("ffi.jl")

end
