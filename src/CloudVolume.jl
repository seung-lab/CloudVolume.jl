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
    resolution


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

CachedVolume = cached(cv.CloudVolume)
CachedStorage = cached(cv.Storage)

struct CloudVolumeWrapper 
	val
    is1based:: Bool
	function CloudVolumeWrapper(storage_string; mip=0,
						bounded=true,
						fill_missing=false,
                        cache=false,
                        progress=false,
						info=nothing,
                       is1based=false)
		return new(CachedVolume(storage_string, mip, 
						bounded, 
						fill_missing,
                        cache,
                        progress,
						info), is1based)
	end
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    t = time()
    if x.is1based
        ret = get(x.val, (  pyslice(slicex.start-1, slicex.stop),
                            pyslice(slicey.start-1, slicey.stop),
                            pyslice(slicez.start-1, slicez.stop)))
    else 
        ret = get(x.val, (  pyslice(slicex.start, slicex.stop+1),
                            pyslice(slicey.start, slicey.stop+1),
                            pyslice(slicez.start, slicez.stop+1)))
    end 
    if size(ret, 4) == 1
        ret = squeeze(ret, 4)
    end 
    
    speed = sizeof(ret) / (time()-t) / 1000000 
    println("cutout speed: $(speed) MB/s")
    return ret
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange, 
                                        slicey::UnitRange, z::Int64)
    arr = get(x.val, (  pyslice(slicex.start,slicex.stop+1),
                        pyslice(slicey.start,slicey.stop+1), z))
    arr = squeeze(arr, (3,4))
    return arr 
end

function Base.setindex!(x::CloudVolumeWrapper, img::Array, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    if x.is1based 
        x.val[:__setitem__]((   pyslice(slicex.start-1, slicex.stop),
                                pyslice(slicey.start-1, slicey.stop),
                                pyslice(slicez.start-1, slicez.stop)), img)
    else 
        x.val[:__setitem__]((   pyslice(slicex.start, slicex.stop+1),
                                pyslice(slicey.start, slicey.stop+1),
                                pyslice(slicez.start, slicez.stop+1)), img)
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


struct StorageWrapper
    val
    function StorageWrapper(storage_string)
        return new(CachedStorage(storage_string))
    end
end

function Base.getindex(x::StorageWrapper, filename)
    d = x.val[:get_file](filename)
    return deserialize(IOBuffer(d))
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

end # module CloudVolume

