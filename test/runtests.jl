using CloudVolume
using Base.Test

include("storage.jl")

@testset "test 3D image reading and saving" begin  
    path = "gs://seunglab/jpwu/test/image/"
    vol = CloudVolumeWrapper(path)
    a = rand(UInt8, 256,256,16)
    @time vol[256:511, 256:511, 16:31] = a
    @time b = vol[256:511, 256:511, 16:31]
    @test all(a.==b)
end

@testset "test 3D image IO with 1-based indexing" begin  
    path = "gs://seunglab/jpwu/test/image/"
    vol = CloudVolumeWrapper(path; is1based=true)
    a = rand(UInt8, 256,256,16)
    @time vol[257:512, 257:512, 17:32] = a
    @time b = vol[257:512, 257:512, 17:32]
    @test all(a.==b)
end

@testset "test segmentation" begin 
    path = "gs://seunglab/jpwu/test/segmentation/"
    # vol = BigArray( d, configDict )
    vol = CloudVolumeWrapper(path; is1based=true)
    a = rand(UInt32, 256,256,16)
    @time vol[257:512, 257:512, 17:32] = a
    @time b = vol[257:512, 257:512, 17:32]
    @test all(a.==b)
end 


@testset "test segmenation with uint64" begin 
    path = "gs://seunglab/jpwu/test/segmentation-uint64/"
    vol = CloudVolumeWrapper(path; is1based=true)
    a = rand(UInt64, 256,256,16)
    @time vol[257:512, 257:512, 17:32] = a
    @time b = vol[257:512, 257:512, 17:32]
    @test all(a.==b)
end 


@testset "test affinity map" begin 
    path = "gs://seunglab/jpwu/test/affinitymap/"
    vol = CloudVolumeWrapper(path; is1based=true )

    a = rand(Float32, 256,256,16,3)
    @time vol[257:512, 257:512, 17:32] = a
    @time b = vol[257:512, 257:512, 17:32]

    @show size(a)
    @show size(b)
    @test all(a.==b)
end 

@testset "test semantic map" begin 
    path = "gs://seunglab/jpwu/test/semanticmap/" 
    a = rand(Float32, 256,256,16,4)
    vol = CloudVolumeWrapper(path; is1based=true)

    @time vol[257:512, 257:512, 17:32] = a
    @time b = vol[257:512, 257:512, 17:32]

    @show size(a)
    @show size(b)
    @test all(a.==b)
end 
