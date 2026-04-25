#!/bin/bash
# Build LD_LIBRARY_PATH from pip-installed nvidia-*-cu12 packages (WSL2).
# Source this, then run Python.
NV_BASE=/usr/local/lib/python3.12/dist-packages/nvidia
LIBS=""
for sub in cublas cuda_cupti cuda_nvcc cuda_nvrtc cuda_runtime cudnn cufft curand cusolver cusparse nccl nvjitlink; do
    for d in "$NV_BASE/$sub/lib" "$NV_BASE/$sub/lib64" "$NV_BASE/$sub/nvvm/lib64"; do
        if [ -d "$d" ]; then
            LIBS="${LIBS}${d}:"
        fi
    done
done
export LD_LIBRARY_PATH="$LIBS${LD_LIBRARY_PATH}"
