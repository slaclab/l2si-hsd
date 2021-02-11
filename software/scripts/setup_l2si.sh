source /cds/sw/ds/ana/conda2/manage/bin/psconda.sh
conda activate ps-4.1.0

pyver=$(python -c "import sys; print(str(sys.version_info.major)+'.'+str(sys.version_info.minor))")
export PYTHONPATH=$RELDIR/install/lib/python$pyver/site-packages

# Python Package directories
export EPIXROGUE_DIR=${PWD}/python
export SURF_DIR=${PWD}/../../firmware/submodules/surf/python

# Setup python path
export PYTHONPATH=${PWD}/python:${EPIXROGUE_DIR}:${SURF_DIR}:${PYTHONPATH}
