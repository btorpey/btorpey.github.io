#!/bin/bash 
set -exv

## modify the following as needed for your environment
# location where gcc should be installed
INSTALL_PREFIX=/build/share/gcc/4.8.2
# number of cores
CPUS=$(nproc)
# uncomment following to get verbose output from make
#VERBOSE=VERBOSE=1
# uncomment following if you need to sudo in order to do the install
#SUDO=sudo


## get everything
wget http://www.netgull.com/gcc/releases/gcc-4.8.2/gcc-4.8.2.tar.bz2
wget https://gmplib.org/download/gmp/gmp-4.3.2.tar.bz2
wget http://www.multiprecision.org/mpc/download/mpc-0.8.1.tar.gz
wget http://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.1.tar.gz
wget ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.12.2.tar.bz2

## untar gcc
tar xf gcc-4.8.2.tar.bz2
## untar prereqs
# gmp
tar xf gmp-4.3.2.tar.bz2
mv gmp-4.3.2 gcc-4.8.2/gmp
# mpc
tar xf mpc-0.8.1.tar.gz
mv mpc-0.8.1 gcc-4.8.2/mpc
# mpfr
tar xf mpfr-2.4.2.tar.bz2
mv mpfr-2.4.2 gcc-4.8.2/mpfr
# cloog
tar xf cloog-0.18.1.tar.gz
mv cloog-0.18.1 gcc-4.8.2/cloog
# isl
tar xf isl-0.12.2.tar.bz2
mv isl-0.12.2 gcc-4.8.2/isl

# build gcc
rm -rf gcc
mkdir gcc
cd gcc
../gcc-4.8.2/configure --prefix=${INSTALL_PREFIX} --enable-languages=c,c++ --disable-multilib
make -j ${CPUS} ${VERBOSE}

# install it
${SUDO} rm -rf ${INSTALL_PREFIX}
${SUDO} make install
