#!/bin/bash

AMDGPU_GFXMODEL=`rocminfo | grep gfx | sed -e 's/Name://' | head -1 |sed 's/ //g'`
BUILD_PYTORCH=0

n=0
while [[ $# -gt 0 ]]
do
   case "${1}" in
      "--rocm-version")
          shift
          ROCM_VERSION=${1}
          ;;
      "--amdgpu-gfxmodel")
          shift
          AMDGPU_GFXMODEL=${1}
          ;;
      "--build-pytorch")
          shift
          BUILD_PYTORCH=${1}
          ;;
      *)  
         last ${1}
         ;;
   esac
   n=$((${n} + 1))
   shift
done

echo ""
echo "==================================="
echo "Starting Pytorch Install with"
echo "BUILD_PYTORCH: $BUILD_PYTORCH" 
echo "ROCM_VERSION: $ROCM_VERSION" 
echo "AMDGPU_GFXMODEL: $AMDGPU_GFXMODEL" 
echo "==================================="
echo ""

if [ "${BUILD_PYTORCH}" = "0" ]; then

   echo "pytorch will not be build, according to the specified value of BUILD_PYTORCH"
   echo "BUILD_PYTORCH: $BUILD_PYTORCH"
   exit

else
   CACHE_FILES=/CacheFiles/${DISTRO}-${DISTRO_VERSION}-rocm-${ROCM_VERSION}-${AMDGPU_GFXMODEL}
   if [ -f ${CACHE_FILES}/pytorch.tgz ]; then
      echo ""
      echo "============================"
      echo " Installing Cached Pytorch"
      echo "============================"
      echo ""

      #install the cached version
      cd /opt/rocmplus-${ROCM_VERSION}
      tar -xzf ${CACHE_FILES}/pytorch.tgz
      chown -R root:root /opt/rocmplus-${ROCM_VERSION}/pytorch
      if [ "${USER}" != "sysadmin" ]; then
         rm ${CACHE_FILES}/pytorch.tgz
      fi
   else
      echo ""
      echo "============================"
      echo " Building Pytorch"
      echo "============================"
      echo ""


      source /etc/profile.d/lmod.sh
      source /etc/profile.d/z01_lmod.sh
      module load rocm
      # Build with GPU aware MPI not working yet
      # Need to use the update-alternatives in openmpi setup to get
      # GPU aware MPI
      #module load openmpi

      sudo DEBIAN_FRONTEND=noninteractive apt-get update
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python-is-python3
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libopenmpi-dev
      
      # unset environment variables that are not needed for pytorch
      unset BUILD_AOMP_LATEST
      unset BUILD_CLACC_LATEST
      unset BUILD_GCC_LATEST
      unset BUILD_LLVM_LATEST
      unset BUILD_OG_LATEST
      unset USE_CACHED_APPS
      unset BUILD_CUPY
      unset BUILD_PYTORCH
      unset BUILD_KOKKOS
      
      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/pytorch/lib/python3.10/site-packages:$PYTHONPATH
      
      # Install of pre-built pytorch for reference
      #sudo pip3 install --target=/opt/rocmplus-${ROCM_VERSION}/pytorch torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
      
      export _GLIBCXX_USE_CXX11_ABI=1
      export ROCM_HOME=${ROCM_PATH}
      export USE_ROCM=1
      export USE_CUDA=0
      export MAX_JOBS=20
      export USE_MPI=1
      export PYTORCH_ROCM_ARCH="${AMDGPU_GFXMODEL}"
      
      export PYTORCH_INSTALL_DIR=/opt/rocmplus-${ROCM_VERSION}/pytorch

      sudo mkdir -p ${PYTORCH_INSTALL_DIR}
      sudo chmod a+w ${PYTORCH_INSTALL_DIR}

      # PyTorch 2.4, Python 3.12

      # This block of code is to retry if git clone fails.
      RETRIES=6
      DELAY=30
      COUNT=1
      while [ $COUNT -lt $RETRIES ]; do
        git clone --recursive --depth 1 --branch v2.4.0 https://github.com/pytorch/pytorch
        if [ $? -eq 0 ]; then
          RETRIES=0
          break
        fi
        let COUNT=$COUNT+1
        sleep $DELAY
      done

      cd pytorch
      # Pytorch 2.4 needs some patches to build for ROCm
      # Fix triton build failure due to tritonlang.blob.core.windows.net not available
      # The download from https://tritonlang.blob.core.windows.net/llvm-builds/ has been
      # blocked and made private. We substitute https://oaitriton.blob.core.windows.net/public/llvm-builds/
      # The pytorch head already has this change, but the pytorch 2.4 does not
      # Patch documentation is at https://github.com/pytorch/pytorch/pull/133694/files
      patch .github/scripts/build_triton_wheel.py < /tmp/pytorch_build_triton_wheel_py.patch
      # The next fix is a ROCm fix. The USE_ROCM define is not passed to the CAFFE2 build
      # https://github.com/pytorch/pytorch/issues/103312
      # We comment out the lines within the USE_ROCM block in the torch/csrc/jit/ir/ir.cpp file
      sed -i -e 's/case cuda/\/\/case cuda/' torch/csrc/jit/ir/ir.cpp
      pip3 install mkl-static mkl-include 
      pip3 install -r requirements.txt
      
      python3 tools/amd_build/build_amd.py >& /dev/null
      
      echo ""
      echo "===================="
      echo "Starting setup.py install"
      echo "===================="
      echo ""
      #export CMAKE_PREFIX_PATH=${PYTORCH_INSTALL_DIR}
      python setup.py install --prefix=${PYTORCH_INSTALL_DIR}
      #python3 setup.py install --prefix=/opt/rocmplus-${ROCM_VERSION}/pytorch
      echo ""
      echo "===================="
      echo "Finished setup.py install"
      echo "===================="
      echo ""

      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/pytorch/lib/python3.10/site-packages
      echo "PYTHONPATH is ${PYTHONPATH}"
      python3 -c 'import torch' 2> /dev/null && echo 'Success' || echo 'Failure'

      cd /tmp

      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/pytorch/lib/python3.10/site-packages
      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/vision/lib/python3.10/site-packages/torchvision-0.19.0a0+48b1edf-py3.10-linux-x86_64.egg:$PYTHONPATH
      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/vision/lib/python3.10/site-packages/pillow-10.4.0-py3.10-linux-x86_64.egg:$PYTHONPATH
      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/audio/lib/python3.10/site-packages/torchaudio-2.4.0a0+69d4077-py3.10-linux-x86_64.egg:$PYTHONPATH
      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/vision/lib/python3.10/site-packages:$PYTHONPATH
      export PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/audio/lib/python3.10/site-packages:$PYTHONPATH

      # install necessary packages in installation directory
      export TORCHVISION_INSTALL_DIR=/opt/rocmplus-${ROCM_VERSION}/vision
      export TORCHAUDIO_INSTALL_DIR=/opt/rocmplus-${ROCM_VERSION}/audio
      sudo mkdir -p ${TORCHVISION_INSTALL_DIR}
      sudo mkdir -p ${TORCHAUDIO_INSTALL_DIR}

      if [[ "${USER}" != "root" ]]; then
         sudo chmod a+w ${TORCHVISION_INSTALL_DIR}
         sudo chmod a+w ${TORCHAUDIO_INSTALL_DIR}
      fi

      git clone --recursive --depth 1 --branch v0.19.0 https://github.com/pytorch/vision
      cd vision
      python3 setup.py install --prefix=${TORCHVISION_INSTALL_DIR}
      cd ..

      git clone --recursive --depth 1 --branch v2.4.0 https://github.com/pytorch/audio
      cd audio
      python3 setup.py install --prefix=${TORCHAUDIO_INSTALL_DIR}

      if [[ "${USER}" != "root" ]]; then
         sudo find ${PYTORCH_INSTALL_DIR} -type f -execdir chown root:root "{}" +
         sudo find ${PYTORCH_INSTALL_DIR} -type d -execdir chown root:root "{}" +
         sudo find ${TORCHVISION_INSTALL_DIR} -type f -execdir chown root:root "{}" +
         sudo find ${TORCHVISION_INSTALL_DIR} -type d -execdir chown root:root "{}" +
         sudo find ${TORCHAUDIO_INSTALL_DIR} -type f -execdir chown root:root "{}" +
         sudo find ${TORCHAUDIO_INSTALL_DIR} -type d -execdir chown root:root "{}" +
      fi

      if [[ "${USER}" != "root" ]]; then
         sudo chmod go-w ${PYTORCH_INSTALL_DIR}
         sudo chmod go-w ${TORCHVISION_INSTALL_DIR}
         sudo chmod go-w ${TORCHAUDIO_INSTALL_DIR}
      fi

      # cleanup
      cd ..
      rm -rf vision audio
      sudo rm -rf /app/pytorch
      sudo rm -rf /tmp/amd_triton_kernel* /tmp/can*

   fi
fi

# Create a module file for Pytorch
export MODULE_PATH=/etc/lmod/modules/ROCmPlus-AI/pytorch

sudo mkdir -p ${MODULE_PATH}

# The - option suppresses tabs
cat <<-EOF | sudo tee ${MODULE_PATH}/2.4.lua
        whatis("HIP version of PyTorch")

        load("rocm/${ROCM_VERSION}")
        conflict("miniconda3")
	prepend_path("PYTHONPATH","/opt/rocmplus-${ROCM_VERSION}/vision/lib/python3.10/site-packages/torchvision-0.19.0a0+48b1edf-py3.10-linux-x86_64.egg")
	prepend_path("PYTHONPATH","/opt/rocmplus-${ROCM_VERSION}/vision/lib/python3.10/site-packages/pillow-10.4.0-py3.10-linux-x86_64.egg")
	prepend_path("PYTHONPATH","/opt/rocmplus-${ROCM_VERSION}/audio/lib/python3.10/site-packages/torchaudio-2.4.0a0+69d4077-py3.10-linux-x86_64.egg")
        prepend_path("PYTHONPATH","/opt/rocmplus-${ROCM_VERSION}/pytorch/lib/python3.10/site-packages")
EOF

#pip download --only-binary :all: --dest /opt/wheel_files_6.0/pytorch-rocm --no-cache --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/rocm6.0
#cat > /opt/wheel_files_6.0/README_pytorch <<-EOF
#        To install the pytorch package for ROCM 6.0
#           pip3 install /opt/wheel_files-6.0/pytorch-rocm/torch-2.3.0.dev20240301+rocm6.0-cp310-cp310-linux_x86_64.whl
#	   pip3 install /opt/wheel_files-6.0/pytorch-rocm/torchvision-0.18.0.dev20240301+rocm6.0-cp310-cp310-linux_x86_64.whl
#EOF

