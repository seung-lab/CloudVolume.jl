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
    flush


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
    arr = squeeze(get(x.val,
            (pyslice(slicex.start, slicex.stop + 1),
            pyslice(slicey.start, slicey.stop + 1),
            pyslice(slicez.start, slicez.stop + 1))), 4)
    x.val[:unlink_shared_memory]()
    return arr
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

    if arr.f_contig
        arr = squeeze(copy(arr), (3, 4))
    else
        arr = transpose(squeeze(
                unsafe_wrap(Array, arr.data, reverse(arr.dims)), (1, 2)))
    end
    x.val[:unlink_shared_memory]()
    return arr
end

function Base.setindex!(x::CloudVolumeWrapper, img::Array, slicex::UnitRange,
                                        slicey::UnitRange, slicez::UnitRange)
    x.val[:__setitem__]((pyslice(slicex.start, slicex.stop + 1),
                            pyslice(slicey.start, slicey.stop + 1),
                            pyslice(slicez.start, slicez.stop + 1)),
                            img)
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
