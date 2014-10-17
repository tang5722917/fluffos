#!/bin/bash

setup () {
sudo apt-get install -qq bison
sudo apt-get install -qq autoconf

# clang needs the updated libstdc++
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get update -qq
sudo apt-get install -qq gcc-4.8 g++-4.8

case $COMPILER in
  gcc)
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 100 --slave /usr/bin/g++ g++ /usr/bin/g++-4.8
    sudo update-alternatives --auto gcc
    sudo update-alternatives --query gcc
    export CXX="/usr/bin/g++"
    $CXX -v
    ;;
  clang)
    sudo wget -q http://llvm.org/releases/3.5.0/clang+llvm-3.5.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    sudo tar axvf clang+llvm-3.5.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz
    export CXX="$PWD/clang+llvm-3.5.0-x86_64-linux-gnu/bin/clang++"
    $CXX -v
    ;;
esac

if [ "$BUILD" = "i386" ]; then
  sudo apt-get remove libevent-dev libevent-* libssl-dev
  sudo apt-get install g++-multilib g++-4.8-multilib
  sudo apt-get --no-install-recommends install valgrind:i386
  sudo apt-get install libevent-2.0-5:i386
  sudo apt-get install libevent-dev:i386
  sudo apt-get --no-install-recommends install libz-dev:i386
else
  sudo apt-get install valgrind
  sudo apt-get install libevent-dev libmysqlclient-dev libsqlite3-dev libpq-dev libz-dev libssl-dev libpcre3-dev
fi
}

# do setup
setup

# stop on first error down below
set -e

# testing part
cd src
./autogen.sh
cp local_options.$CONFIG local_options

if [ -n "$GCOV" ]; then
  ./build.FluffOS $TYPE --enable-gcov=yes
else
  ./build.FluffOS $TYPE
fi

make -j 2
cd testsuite

if [ -n "$GCOV" ]; then
  # run in gcov mode and submit the result
  ../driver etc/config.test -ftest -d
  cd ..
  sudo pip install cpp-coveralls
  coveralls --exclude packages --exclude thirdparty --exclude testsuite --exclude-pattern '.*.tab.+$' --gcov /usr/bin/gcov-4.8 --gcov-options '\-lp' -r $PWD -b $PWD
else
  valgrind --malloc-fill=0x75 --free-fill=0x73 --track-origins=yes --leak-check=full ../driver etc/config.test -ftest -d
fi