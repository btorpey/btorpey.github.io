#!/bin/bash
#
# Copyright 2016 by Bill Torpey. All Rights Reserved.
# This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivs 3.0 United States License.
# http://creativecommons.org/licenses/by-nc-nd/3.0/us/deed.en
#
set -exv

VERSION=7.11

# fugly hack for python support
# (see https://sourceware.org/gdb/wiki/CrossCompilingWithPythonSupport)
WITH_PYTHON=$(/bin/pwd)/python-hack.sh

# location where gcc should be installed
INSTALL_PREFIX=/build/share/gdb/${VERSION}
# number of cores
CPUS=$(nproc)
# uncomment following to get verbose output from make
#VERBOSE=VERBOSE=1

[[ -e gdb-${VERSION}.tar.gz ]] || wget -nv http://ftp.gnu.org/gnu/gdb/gdb-${VERSION}.tar.gz

rm -rf gdb-${VERSION}
tar xvfz gdb-${VERSION}.tar.gz

rm -rf build
mkdir build
cd build
../gdb-${VERSION}/configure --prefix=${INSTALL_PREFIX} --with-python=${WITH_PYTHON}
make -j ${CPUS} ${VERBOSE}

# install it
rm -rf ${INSTALL_PREFIX}
make install
