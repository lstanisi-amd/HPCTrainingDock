#!/bin/bash

# Autodetect defaults
DISTRO=`cat /etc/os-release | grep '^NAME' | sed -e 's/NAME="//' -e 's/"$//' | tr '[:upper:]' '[:lower:]' `
DISTRO_VERSION=`cat /etc/os-release | grep '^VERSION_ID' | sed -e 's/VERSION_ID="//' -e 's/"$//' | tr '[:upper:]' '[:lower:]' `
DISTRO_CODENAME=`cat /etc/os-release | grep '^VERSION_CODENAME' | sed -e 's/VERSION_CODENAME=//' -e 's/"$//' | tr '[:upper:]' '[:lower:]' `
SUDO="sudo"
DEBIAN_FRONTEND_MODE="DEBIAN_FRONTEND=noninteractive"

if [  -f /.singularity.d/Singularity ]; then
   SUDO=""
   DEBIAN_FRONTEND_MODE=""
fi


echo ""
echo "==================================="
echo "Starting BaseOSPackages Install with"
echo "DISTRO: $DISTRO" 
echo "DISTRO_VERSION: $DISTRO_VERSION" 
echo "DISTRO_CODENAME is $DISTRO_CODENAME"
echo "==================================="
echo ""

if [ "${DISTRO}" = "ubuntu" ]; then
   # Not needed -- should already be these owner/permissions
   #${SUDO} chown -Rv _apt:root /var/cache/apt/archives/partial/
   #${SUDO} chmod -Rv 700 /var/cache/apt/archives/partial/

   export DEBIAN_FRONTEND=noninteractive
   # Python3-dev and python3-venv are for AI/ML
   # Make sure we have a default compiler for the system -- gcc, g++, gfortran
   SUDO_COMMAND=`which sudo`
   if [ "${SUDO_COMMAND}" != "/usr/bin/sudo" ]; then
      apt-get -q -y update
      apt-get -q -y install ${SUDO}
   fi
   ${SUDO} apt-get -q -y update
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get dist-upgrade -y
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get install -q -y build-essential cmake libnuma1 wget gnupg2 m4 bash-completion git-core autoconf libtool autotools-dev \
      lsb-release libpapi-dev libpfm4-dev libudev1 rpm librpm-dev curl apt-utils vim tmux rsync ${SUDO} \
      bison flex texinfo libnuma-dev pkg-config libibverbs-dev rdmacm-utils ssh locales gpg ca-certificates \
      gcc g++ gfortran ninja-build

# Install python packages
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get install -q -y python3-pip python3-dev python3-venv

   ${SUDO} ${DEBIAN_FRONTEND_MODE} localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
fi

if [ "${DISTRO}" = "opensuse leap" ]; then
   ${SUDO} zypper update -y && \
   ${SUDO} zypper dist-upgrade -y && \
   ${SUDO} zypper install -y -t pattern devel_basis && \
   ${SUDO} zypper install -y python3-pip openmpi3-devel gcc-c++ git libnuma-devel dpkg-devel rpm-build wget curl binutils-gold
fi

if [ "${DISTRO}" = "rocky linux" ]; then
   ${SUDO} yum groupinstall -y "Development Tools"
   ${SUDO} yum install -y ${SUDO}
   ${SUDO} yum install -y epel-release
   ${SUDO} yum install -y --allowerasing curl dpkg-devel numactl-devel openmpi-devel papi-devel python3-pip wget zlib-devel 
   ${SUDO} yum clean all
fi

if [[ `which python3-pip | wc -l` -ge 1 ]]; then
   ${SUDO} python3 -m pip install 'cmake==3.28.3'
else
   # Instructions from https://apt.kitware.com/
   # Remove standard version installed with ubuntu packages
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get purge --auto-remove -y cmake

   # Step 1
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get -y update
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get install -y ca-certificates gpg wget
   # Step 2
   test -f /usr/share/doc/kitware-archive-keyring/copyright || \
      wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
      gpg --dearmor - | ${SUDO} tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
   # Step 3
   echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${DISTRO_CODENAME} main" | \
      ${SUDO} tee /etc/apt/sources.list.d/kitware.list >/dev/null
   # Step 4
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get -y update
   test -f /usr/share/doc/kitware-archive-keyring/copyright || \
      ${SUDO} rm /usr/share/keyrings/kitware-archive-keyring.gpg
   # Step 5
   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get install -y kitware-archive-keyring

   ${SUDO} ${DEBIAN_FRONTEND_MODE} apt-get install -y cmake
   CMAKE_VERSION=`cmake --version`
   echo "Installed latest version of cmake ($CMAKE_VERSION)"
fi
