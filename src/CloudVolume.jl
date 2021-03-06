"""
Credit to @jonathanzung for an earlier Precomputed version
"""

module CloudVolume

export
    CloudVolumeWrapper,
    StorageWrapper,
    offset,
    scale,
    chunks,
    resolution,
    exists,
    flush,
    upload_from_shared_memory


using PyCall
@pyimport cloudvolume as cv
const pyslice = pybuiltin(:slice)

function cached(f)
    cache = Dict()
    function my_f(args...; kwargs...)
        if !haskey(cache, [args, kwargs])
            cache[[args, kwargs]] = f(args...; kwargs...)
        end
        return cache[[args, kwargs]]
    end
end

CachedVolume = cached(cv.CloudVolume)
CachedStorage = cached(cv.Storage)

immutable CloudVolumeWrapper
    val::PyObject
    function CloudVolumeWrapper(storage_string::AbstractString;
            mip::Integer = 0,
            bounded::Bool = true,
            autocrop::Bool = false,
            fill_missing::Bool = false,
            cache::Union{Bool,AbstractString} = false,
            cdn_cache::Union{Bool,Integer,AbstractString} = false,
            progress::Bool = false,
            info::Union{Dict,Void} = nothing,
            provenance::Union{Dict,Void} = nothing,
            compress::Union{Bool,AbstractString,Void} = nothing,
            non_aligned_writes::Bool = false,
            parallel::Union{Bool,Integer} = false,
            output_to_shared_memory::Union{Bool,AbstractString} = false)
        return new(CachedVolume(storage_string,
            mip = mip,
            bounded = bounded,
            autocrop = autocrop,
            fill_missing = fill_missing,
            cache = cache,
            cdn_cache = cdn_cache,
            progress = progress,
            info = info,
            provenance = provenance,
            compress = compress,
            non_aligned_writes = non_aligned_writes,
            parallel = parallel,
            output_to_shared_memory = output_to_shared_memory))
    end
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange,
                                        slicey::UnitRange, slicez::UnitRange)
    arr = pycall(x.val[:__getitem__], PyArray,
            (pyslice(slicex.start, slicex.stop + 1),
            pyslice(slicey.start, slicey.stop + 1),
            pyslice(slicez.start, slicez.stop + 1)))

    RetType = x.val[:output_to_shared_memory] ? SharedArray{arr.info.T, 3} :
            Array{arr.info.T, 3}

    if arr.c_contig
        arr.dims = arr.dims[2:4]
        ret = RetType(reverse(arr.dims))
        permutedims!(ret,
                unsafe_wrap(Array, arr.data, reverse(arr.dims)), (3,2,1))
    else
        arr.dims = arr.dims[1:3]
        if x.val[:output_to_shared_memory]
            shmid = x.val[:shared_memory_id]
            ret = RetType("/dev/shm/$(shmid)", arr.dims)
        else
            ret = copy(arr)
        end
    end

    if x.val[:output_to_shared_memory]
        x.val[:unlink_shared_memory]()
        arr.o[:__del__]()
    end
    
    return ret
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange,
                                        slicey::UnitRange, z::Integer)
    slices = (pyslice(slicex.start, slicex.stop + 1),
            pyslice(slicey.start, slicey.stop + 1),
            z)

    # See https://github.com/JuliaPy/PyCall.jl/blob/master/src/numpy.jl#L342
    # This version is faster than above, because we know CloudVolume returns
    # a 4D Array with two dimensions set to '1'. That means we can squeeze()
    # and transpose(), rather than having to use 4D-permutedims()
    arr = pycall(x.val[:__getitem__], PyArray, slices)

    RetType = x.val[:output_to_shared_memory] ? SharedArray{arr.info.T, 2} :
            Array{arr.info.T, 2}

    if arr.c_contig
        arr.dims = arr.dims[3:4]
        ret = RetType(reverse(arr.dims))
        transpose!(ret, unsafe_wrap(Array, arr.data, reverse(arr.dims)))
    else
        arr.dims = arr.dims[1:2]
        if x.val[:output_to_shared_memory]
            shmid = x.val[:shared_memory_id]
            ret = RetType("/dev/shm/$(shmid)", arr.dims)
        else
            ret = copy(arr)
        end
    end

    if x.val[:output_to_shared_memory]
        x.val[:unlink_shared_memory]()
        arr.o[:__del__]()
    end

    return ret
end

function Base.setindex!(x::CloudVolumeWrapper, img::AbstractArray,
        slicex::UnitRange, slicey::UnitRange, slicez::UnitRange)
    x.val[:__setitem__]((pyslice(slicex.start, slicex.stop + 1),
            pyslice(slicey.start, slicey.stop + 1),
            pyslice(slicez.start, slicez.stop + 1)),
            img)
end

function upload_from_shared_memory(x::CloudVolumeWrapper,
        img::AbstractArray, slicex::UnitRange, slicey::UnitRange,
        slicez::UnitRange, cutout_slicex::Union{UnitRange,Void} = nothing,
        cutout_slicey::Union{UnitRange,Void} = nothing,
        cutout_slicez::Union{UnitRange,Void} = nothing)

    new_shm_seg_name = ""
    if !(img isa SharedArray) || !isfile(img.segname)
        warn("No shared memory file exists - need to create a new copy")
        new_shm_seg_name = "/dev/shm/cvjl_$(lpad(string(getpid() % 10^6), 6, "0"))_$(randstring(15))"
        new_img = SharedArray{eltype(img)}(new_shm_seg_name, size(img); mode="w+")
        copy!(new_img, img)
        img = new_img
    end

    slices = (
        pyslice(slicex.start, slicex.stop + 1),
        pyslice(slicey.start, slicey.stop + 1),
        pyslice(slicez.start, slicez.stop + 1)
    )

    cutout_slices = nothing
    if !(cutout_slicex isa Void && cutout_slicey isa Void &&
            cutout_slicez isa Void)
        cutout_slices = (
            pyslice(cutout_slicex.start, cutout_slicex.stop + 1),
            pyslice(cutout_slicey.start, cutout_slicey.stop + 1),
            pyslice(cutout_slicez.start, cutout_slicez.stop + 1)
        )
    end

    x.val[:upload_from_shared_memory](basename(img.segname), slices, cutout_slices)

    if !isempty(new_shm_seg_name)
        rm(new_shm_seg_name)
        finalize(img)
    end
end

function Base.size(x::CloudVolumeWrapper)
    return x.val[:shape]
end

function offset(x::CloudVolumeWrapper)
    return x.val[:voxel_offset]
end

function scale(x::CloudVolumeWrapper)
    return x.val[:mip]
end

function chunks(x::CloudVolumeWrapper)
    return x.val[:underlying]
end

function resolution(x::CloudVolumeWrapper)
    return x.val[:resolution]
end

function Base.flush(x::CloudVolumeWrapper)
    return x.val[:flush_cache]()
end

function Base.info(x::CloudVolumeWrapper)
    return x.val[:info]
end

function provenance(x::CloudVolumeWrapper)
    return x.val[:provenance]
end

immutable StorageWrapper
    val
    function StorageWrapper(storage_string)
        return new(CachedStorage(storage_string))
    end
end

function Base.getindex(x::StorageWrapper, filename::String)
    d = x.val[:get_file](filename)
    return deserialize(IOBuffer(d))
end

function Base.getindex(x::StorageWrapper, filenames::Array{String,1})
    results = x.val[:get_files](filenames)
    empties = filter(x -> x["content"] == nothing, results)
    errors = filter(x -> x["error"] != nothing, results)
    filter!(x -> (x["error"] == nothing) & (x["content"] != nothing), results)
    for r in results
        r["content"] = deserialize(IOBuffer(r["content"]))
    end
    return results, empties, errors
end

function Base.setindex!(x::StorageWrapper, content, filename)
    b = IOBuffer()
    serialize(b, content)
    x.val[:put_file](filename, pybytes(take!(b)))
    x.val[:wait]()
end

function Base.delete!(x::StorageWrapper, filename)
    x.val[:delete_file](filename)
    x.val[:wait]()
end

function exists(x::StorageWrapper, filename)
    return x.val[:exists](filename)
end

end # module CloudVolume
