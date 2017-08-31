"""
Credit to @jonathanzung for an earlier Precomputed version
"""

module CloudVolume

export CloudVolumeWrapper

using PyCall
@pyimport cloudvolume as cv
const pyslice=pybuiltin(:slice)

function cached(f)
	cache=Dict()
	function my_f(args...)
		if !haskey(cache, args)
			cache[args] = f(args...)
		else
			println("restoring from cache")
		end
		return cache[args]
	end
end

CachedVolume = cached(cv.CloudVolume)

immutable CloudVolumeWrapper
	val
	function CloudVolumeWrapper(storage_string, scale_idx=0,
						bounded=true,
						fill_missing=false,
						info=nothing)
		return new(CachedVolume(storage_string, scale_idx, 
						bounded, 
						fill_missing, 
						info))
	end
end

function Base.getindex(x::CloudVolumeWrapper, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    return squeeze(get(x.val, 
            (pyslice(slicex.start,slicex.stop+1),
            pyslice(slicey.start,slicey.stop+1),
            pyslice(slicez.start,slicez.stop+1))),4)
end

function Base.setindex!(x::CloudVolumeWrapper, img::Array, slicex::UnitRange, 
                                        slicey::UnitRange, slicez::UnitRange)
    x.val[:__setitem__]((pyslice(slicex.start,slicex.stop+1),
                            pyslice(slicey.start,slicey.stop+1),
                            pyslice(slicez.start,slicez.stop+1)), 
                            img)
end

end # module CloudVolume
