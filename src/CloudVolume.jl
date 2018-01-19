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
const pyslice=pybuiltin(:slice)

function cached(f)
	cache=Dict()
	function my_f(args...)
		if !haskey(cache, args)
			cache[args] = f(args...)
		end
		return cache[args]
	end
end

CachedVolume = cached(cv.CloudVolumeGSUtil)
CachedStorage = cached(cv.Storage)

immutable CloudVolumeWrapper
	val
	function CloudVolumeWrapper(storage_string; mip=0,
						bounded=true,
						fill_missing=false,
                        cdn_cache=false,
                        progress=false,
						info=nothing,
                        provenance=nothing)
		return new(CachedVolume(storage_string, mip, 
						bounded, 
						fill_missing,
                        cdn_cache,
                        progress,
						info,
                        provenance))
	end
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    return squeeze(get(x.val, 
            (pyslice(slicex.start,slicex.stop+1),
            pyslice(slicey.start,slicey.stop+1),
            pyslice(slicez.start,slicez.stop+1))),4)
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange, 
                                        slicey::UnitRange, z::Int64)
    return squeeze(get(x.val, 
            (pyslice(slicex.start,slicex.stop+1),
            pyslice(slicey.start,slicey.stop+1),
            z)),(3,4))
end

function Base.setindex!(x::CloudVolumeWrapper, img::Array, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    x.val[:__setitem__]((pyslice(slicex.start,slicex.stop+1),
                            pyslice(slicey.start,slicey.stop+1),
                            pyslice(slicez.start,slicez.stop+1)), 
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
    empties = filter(x->x["content"]==nothing, results)
    errors = filter(x->x["error"]!=nothing, results)
    filter!(x->(x["error"]==nothing) & (x["content"]!=nothing), results)
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

