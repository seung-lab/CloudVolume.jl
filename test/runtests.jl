using CloudVolume
using Base.Test

include("cloudvolume.jl")
@test test_storage();
