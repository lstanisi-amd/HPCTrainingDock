#/bin/bash

# Variables controlling setup process
ROCM_VERSION=6.0
BUILD_CUPY=0

# Autodetect defaults
AMDGPU_GFXMODEL=`rocminfo | grep gfx | sed -e 's/Name://' | head -1 |sed 's/ //g'`

usage()
{
   echo "--amdgpu-gfxmodel [ AMDGPU-GFXMODEL ] default autodetected"
   echo "--rocm-version [ ROCM_VERSION ] default $ROCM_VERSION"
   echo "--build-cupy"
}

send-error()
{
    usage
    echo -e "\nError: ${@}"
    exit 1
}

reset-last()
{
   last() { send-error "Unsupported argument :: ${1}"; }
}

n=0
while [[ $# -gt 0 ]]
do
   case "${1}" in
      "--rocm-version")
          shift
          ROCM_VERSION=${1}
	  reset-last
          ;;
      "--amdgpu-gfxmodel")
          shift
          AMDGPU_GFXMODEL=${1}
	  reset-last
          ;;
      "--build-cupy")
          shift
          BUILD_CUPY=${1}
	  reset-last
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
echo "Starting Cupy Install with"
echo "ROCM_VERSION: $ROCM_VERSION" 
echo "AMDGPU_GFXMODEL: $AMDGPU_GFXMODEL" 
echo "BUILD_CUPY: $BUILD_CUPY" 
echo "==================================="
echo ""

if [ "${BUILD_CUPY}" = "0" ]; then

   echo "CuPy will not be built, according to the specified value of BUILD_CUPY"
   echo "BUILD_CUPY: $BUILD_CUPY"
   exit

else 
   cd /tmp

   if [ -f /opt/rocmplus-${ROCM_VERSION}/CacheFiles/cupy.tgz ]; then
      echo ""
      echo "============================"
      echo " Installing Cached CuPy"
      echo "============================"
      echo ""

      #install the cached version
      cd /opt/rocmplus-${ROCM_VERSION}
      sudo chmod u+w /opt/rocmplus-${ROCM_VERSION}
      tar -xzf CacheFiles/cupy.tgz
      chown -R root:root /opt/rocmplus-${ROCM_VERSION}/cupy
      sudo rm /opt/rocmplus-${ROCM_VERSION}/CacheFiles/cupy.tgz
      sudo chmod u-w /opt/rocmplus-${ROCM_VERSION}
   else
      echo ""
      echo "============================"
      echo " Building CuPy"
      echo "============================"
      echo ""

      # Load the ROCm version for this CuPy build
      source /etc/profile.d/lmod.sh
      module load rocm/${ROCM_VERSION}
      
      # Load the ROCm version for this CuPy build -- use hip compiler, path to ROCm and the GPU model
      export CUPY_INSTALL_USE_HIP=1
      export ROCM_HOME=${ROCM_PATH}
      export HCC_AMDGPU_ARCH=${AMDGPU_GFXMODEL}
      
      # Get source from the ROCm repository of CuPy.
      git clone -q --depth 1 --recursive https://github.com/ROCm/cupy.git
      cd cupy
      
      # use version 1.25 of numpy – need to test with later numpy version
      sed -i -e '/numpy/s/1.27/1.25/' setup.py
      # set python path to installation directory
      PYTHONPATH=/opt/rocmplus-${ROCM_VERSION}/cupy
      # build basic cupy package
      python3 setup.py -q bdist_wheel
      
      # install necessary packages in installation directory
      sudo mkdir -p /opt/rocmplus-${ROCM_VERSION}/cupy
      sudo chmod a+w /opt/rocmplus-${ROCM_VERSION}/cupy
      pip3 install pytest mock
      pip3 install -v --target=/opt/rocmplus-${ROCM_VERSION}/cupy dist/cupy-13.0.0b1-cp310-cp310-linux_x86_64.whl
      sudo -R chown root /opt/rocmplus-${ROCM_VERSION}/cupy
      sudo -R chgrp root /opt/rocmplus-${ROCM_VERSION}/cupy
      sudo chmod go-w /opt/rocmplus-${ROCM_VERSION}/cupy
      
      # cleanup
      cd ..
      rm -rf cupy
      module unload rocm/${ROCM_VERSION}
   fi
      
   # Create a module file for cupy
   export MODULE_PATH=/etc/lmod/modules/ROCmPlus-AI/cupy
   
   sudo mkdir -p ${MODULE_PATH}
   
   # The - option suppresses tabs
   cat <<-EOF | sudo tee ${MODULE_PATH}/13.0.0b1.lua
	whatis("HIP version of CuPy")

	load("rocm/${ROCM_VERSION}")
	prepend_path("PYTHONPATH","/opt/rocmplus-${ROCM_VERSION}/cupy")
EOF

fi
