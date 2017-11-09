using CloudVolume
using Base.Test

function test_storage()
    s = StorageWrapper("gs://neuroglancer/pinky40_alignment/test")
    s["a"] = "b"
    @assert s["a"] == "b"
    delete!(s, "a")
    return true
end
