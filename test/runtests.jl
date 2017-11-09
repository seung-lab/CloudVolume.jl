using CloudVolume
using Base.Test

path = "gs://seunglab/jpwu/test/image/"
ba = CloudVolumeWrapper(path)

a = rand(UInt8, 256,256,16)

@testset "test 3D image reading and saving" begin  
    # ba = BigArray(d, UInt8, (128,128,8))
    @time ba[257:512, 257:512, 17:32] = a
    # BigArrays.mysetindex!(ba, a, (201:400, 201:400, 161:116))
    @time b = ba[257:512, 257:512, 17:32]
    @test all(a.==b)
end

@testset "test single voxel indexing" begin 
    x = a[1,1,1]
    y = ba[257,257,17]
    @test x==y
end 

@testset "test segmentation" begin 
    path = "gs://seunglab/jpwu/test/segmentation/"
    # ba = BigArray( d, configDict )
    ba = CloudVolumeWrapper(path)
    a = rand(UInt32, 256,256,16)
    @time ba[257:512, 257:512, 17:32] = a
    @time b = ba[257:512, 257:512, 17:32]
    @test all(a.==b)
end 


@testset "test segmenation with uint64" begin 
    path = "gs://seunglab/jpwu/test/segmentation-uint64/"
    ba = CloudVolumeWrapper(path)
    a = rand(UInt64, 256,256,16)
    @time ba[257:512, 257:512, 17:32] = a
    @time b = ba[257:512, 257:512, 17:32]
    @test all(a.==b)
end 


@testset "test affinity map" begin 
    path = "gs://seunglab/jpwu/test/affinitymap/"
    ba = CloudVolumeWrapper(path)

    a = rand(Float32, 256,256,16,3)
    @time ba[257:512, 257:512, 17:32, 1:3] = a
    @time b = ba[257:512, 257:512, 17:32, 1:3]

    @show size(a)
    @show size(b)
    @test all(a.==b)
end 

@testset "test semantic map" begin 
    path = "gs://seunglab/jpwu/test/semanticmap/" 
    a = rand(Float32, 256,256,16,4)
    ba = CloudVolumeWrapper(path)

    @time ba[257:512, 257:512, 17:32, 1:4] = a
    @time b = ba[257:512, 257:512, 17:32, 1:4]

    @show size(a)
    @show size(b)
    @test all(a.==b)
end 
