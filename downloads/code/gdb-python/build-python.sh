#!/bin/bash
#
# Copyright 2016 by Bill Torpey. All Rights Reserved.
# This work is licensed under a Creative Commons Attribution-NonCommercial-NoDerivs 3.0 United States License.
# http://creativecommons.org/licenses/by-nc-nd/3.0/us/deed.en
#
set -exv

VERSION=2.7.11

## modify the following as needed for your environment
# location where gcc should be installed
INSTALL_PREFIX=/build/share/python/${VERSION}
# number of cores
CPUS=1
# uncomment following to get verbose output from make
#VERBOSE=VERBOSE=1

## download
[[ -e Python-${VERSION}.tgz ]]   || wget -nv https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tgz

## untar
rm -rf Python-${VERSION}
tar xf Python-${VERSION}.tgz

# build
cd Python-${VERSION}
./configure --prefix=${INSTALL_PREFIX} --enable-shared \
LDFLAGS="-Wl,--rpath=${INSTALL_PREFIX}/lib"

make -j ${CPUS} ${VERBOSE}

# install it
rm -rf ${INSTALL_PREFIX}
make install
