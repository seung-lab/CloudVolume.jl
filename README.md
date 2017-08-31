# CloudVolume

[![Build Status](https://travis-ci.org/macrintr/CloudVolume.jl.svg?branch=master)](https://travis-ci.org/macrintr/CloudVolume.jl)

[![Coverage Status](https://coveralls.io/repos/macrintr/CloudVolume.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/macrintr/CloudVolume.jl?branch=master)

[![codecov.io](http://codecov.io/github/macrintr/CloudVolume.jl/coverage.svg?branch=master)](http://codecov.io/github/macrintr/CloudVolume.jl?branch=master)

Julia wrapper for cloud-volume from Python.

## Installation  
Install cloud-volume, e.g.
```
pip install cloud-volume  
```

Clone this package,
```
Pkg.clone("https://github.com/seung-lab/CloudVolume.jl")
```

## Quickstart
Note that indexing is inclusive, like Julia.
```
using CloudVolume
vol = CloudVolumeWrapper("path location to precomputed files")
img = vol[1000:1100, 2000:2100, 100:200]  # download images
vol[1000:1100, 2000:2100, 100:200] = img  # upload images
```

Note that uploaded data must be chunk-aligned. For more details, see the [cloud-volume documentation](https://github.com/seung-lab/cloud-volume#cloud-volume).

## Credits
Thanks to @jonathanzung for an earlier version of this wrapper.
