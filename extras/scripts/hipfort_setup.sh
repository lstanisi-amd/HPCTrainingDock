#/bin/bash

# Variables controlling setup process
MODULE_PATH=/etc/lmod/modules/ROCmPlus-LatestCompilers/hipfort
BUILD_HIPFORT=0
ROCM_VERSION=6.0.0
HIPFORT_PATH="/opt/rocmplus-${ROCM_VERSION}/hipfort"
HIPFORT_PATH_INPUT=""
FC_COMPILER=gfortran

SUDO="sudo"

if [  -f /.singularity.d/Singularity ]; then
   SUDO=""
fi

usage()
{
   echo "Usage:"
   echo "  --module-path [ MODULE_PATH ] default $MODULE_PATH"
   echo "  --rocm-version [ ROCM_VERSION ] default $ROCM_VERSION"
   echo "  --build-hipfort [ BUILD_HIPFORT ], set to 1 to build hipfort, default is $BUILD_HIPFORT"
   echo "  --fc-compiler [FC_COMPILER: gfortran|amdflang-new|cray-ftn], default is $FC_COMPILER"
   echo "  --install-path [ HIPFORT_PATH ], default is $HIPFORT_PATH"
   echo "  --help: this usage information"
   exit 1
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
      "--build-hipfort")
          shift
          BUILD_HIPFORT=${1}
          reset-last
          ;;
      "--help")
          usage
          ;;
      "--module-path")
          shift
          MODULE_PATH=${1}
          reset-last
          ;;
      "--install-path")
          shift
          HIPFORT_PATH_INPUT=${1}
          reset-last
          ;;
      "--fc-compiler")
          shift
          FC_COMPILER=${1}
          reset-last
          ;;
      "--rocm-version")
          shift
          ROCM_VERSION=${1}
          reset-last
          ;;
      "--*")
          send-error "Unsupported argument at position $((${n} + 1)) :: ${1}"
          ;;
      *)
         last ${1}
         ;;
   esac
   n=$((${n} + 1))
   shift
done

if [ "${HIPFORT_PATH_INPUT}" != "" ]; then
   HIPFORT_PATH=${HIPFORT_PATH_INPUT}
else
   # override path in case ROCM_VERSION has been supplied as input
   HIPFORT_PATH=/opt/rocmplus-${ROCM_VERSION}/hipfort
fi

echo ""
echo "==================================="
echo "Starting Hipfort Install with"
echo "ROCM_VERSION: $ROCM_VERSION"
echo "BUILD_HIPFORT: $BUILD_HIPFORT"
echo "MODULE_PATH: $MODULE_PATH"
echo "HIPFORT_PATH: $HIPFORT_PATH"
echo "FC_COMPILER: $FC_COMPILER"
echo "==================================="
echo ""

if [ "${BUILD_HIPFORT}" = "0" ]; then

   echo "Hipfort will not be built, according to the specified value of BUILD_HIPFORT"
   echo "BUILD_HIPFORT: $BUILD_HIPFORT"
   exit

else
   if [ -f /opt/rocmplus-${ROCM_VERSION}/CacheFiles/hipfort.tgz ]; then
      echo ""
      echo "============================"
      echo " Installing Cached Hipfort"
      echo "============================"
      echo ""

      #install the cached version
      cd /opt/rocmplus-${ROCM_VERSION}
      tar -xzf CacheFiles/hipfort.tgz
      chown -R root:root /opt/rocmplus-${ROCM_VERSION}/hipfort
      ${SUDO} rm /opt/rocmplus-${ROCM_VERSION}/CacheFiles/hipfort.tgz

   else
      echo ""
      echo "============================"
      echo " Building Hipfort"
      echo "============================"
      echo ""

      if  [ "${BUILD_HIPFORT}" = "0" ]; then

      source /etc/profile.d/lmod.sh
      source /etc/profile.d/z01_lmod.sh
      module load rocm/${ROCM_VERSION}

      HIPFORT_PATH=/opt/rocmplus-${ROCM_VERSION}/hipfort
      ${SUDO} mkdir -p ${HIPFORT_PATH}

      git clone --branch rocm-${ROCM_VERSION} https://github.com/ROCm/hipfort.git
      cd hipfort

      mkdir build
      cd build

      if [ "${FC_COMPILER}" = "gfortran" ]; then
         cmake -DHIPFORT_INSTALL_DIR=${HIPFORT_PATH} ..
      elif [ "${FC_COMPILER}" = "amdflang-new" ]; then
         module load amdflang-new-beta-drop
         cmake -DHIPFORT_INSTALL_DIR=${HIPFORT_PATH} -DHIPFORT_COMPILER=$FC -DHIPFORT_COMPILER_FLAGS="-ffree-form -cpp" ..
      elif [ "${FC_COM{ILER}" = "cray-ftn" ]; then
         cmake -DHIPFORT_INSTALL_DIR=$HIPFORT_PATH -DHIPFORT_BUILD_TYPE=RELEASE -DHIPFORT_COMPILER=$(which ftn) -DHIPFORT_COMPILER_FLAGS="-ffree -eT" -DHIPFORT_AR=$(which ar) -DHIPFORT_RANLIB=$(which ranlib) ..
      else
         echo " ERROR: requested compiler is not currently among the available options "
         echo " Please choose one among: gfortran (default), amdflang-new, cray-ftn "
         exit 1
      fi

      ${SUDO} make install

      cd ../..
      ${SUDO} rm -rf hipfort

   fi

   if [ ! -w ${MODULE_PATH} ]; then
      SUDO="sudo"
   fi
   # Create a module file for hipfort
   ${SUDO} mkdir -p ${MODULE_PATH}

   # The - option suppresses tabs
   cat <<-EOF | ${SUDO} tee ${MODULE_PATH}/${ROCM_VERSION}.lua
	whatis(" hipfc: Wrapper to call Fortran compiler with hipfort. Also calls hipcc for non Fortran files. ")
        whatis(" this hipfort build has been compiled with: $FC_COMPILER. ")
        local fc-compiler = $FC_COMPILER
        if fc-compiler == "amdflang-new" then
		load("amdflang-new-beta-drop")
        end
	load("rocm/${ROCM_VERSION}")
	prepend_path("PATH","${HIPFORT_PATH}/bin")
EOF

fi

