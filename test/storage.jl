using CloudVolume
using Base.Test

@testset "test StorageWrapper" begin 
    s = StorageWrapper("gs://neuroglancer/pinky40_alignment/test")
    s["a"] = "b"
    @test s["a"] == "b"
    delete!(s, "a")
end
