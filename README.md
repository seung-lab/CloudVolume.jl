# CloudVolume

[![Build Status](https://travis-ci.org/macrintr/CloudVolume.jl.svg?branch=master)](https://travis-ci.org/macrintr/CloudVolume.jl)

[![Coverage Status](https://coveralls.io/repos/macrintr/CloudVolume.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/macrintr/CloudVolume.jl?branch=master)

[![codecov.io](http://codecov.io/github/macrintr/CloudVolume.jl/coverage.svg?branch=master)](http://codecov.io/github/macrintr/CloudVolume.jl?branch=master)

Julia wrapper for cloud-volume from Python.

## Installation  
Install cloud-volume, following the steps in its [documentation](https://github.com/seung-lab/cloud-volume#cloud-volume).

Within Julia, clone this package,
```
Pkg.clone("https://github.com/seung-lab/CloudVolume.jl")
```

## Quickstart
Note that indexing is inclusive, like Julia.
```
using CloudVolume
# CloudVolume object
vol = CloudVolumeWrapper("<path to precomputed file directory>")
img = vol[1000:1100, 2000:2100, 100:200]  # download images
vol[1000:1100, 2000:2100, 100:200] = img  # upload images
# Storage object
s = StorageWrapper("<path to storage directory>")
s["filename"] = "content"
s["filename"] == "content" # returns true
delete!(s, "filename")
```

Note that uploaded CloudVolume data must be chunk-aligned. For more details, see the [cloud-volume documentation](https://github.com/seung-lab/cloud-volume#cloud-volume).

## Troubleshooting  
If you installed the CloudVolume Python package inside a virtualenv, you many need to rebuild `PyCall` to use that virtualenv.
1. Activate the virtualenv you created.
1. Open Julia.
1. Run `rm(Pkg.dir("PyCall","deps","PYTHON")); Pkg.build("PyCall")`

## Credits
Thanks to @jonathanzung for an earlier version of this wrapper.
