set -xe

#############################################################
### CONFIG
#############################################################

#############################################################
### DERIVED CONFIG
#############################################################

#export SYS_ROOT=$SYSROOT
export PATH=${TOOLCHAIN_BIN}:${PATH}
export PREFIX=$DEV_PREFIX
export BUILD_FOLDER=./$BUILDDIR
#export PREFIX=${BUILD_ROOT}/toolchain/$ABI

mkdir -p ${PREFIX}

echo $SYS_ROOT $BUILD_ROOT $PATH $PREFIX


strip(){
	if [ $STRIPPING == 'ON' ]; then
		SO_FILES=$(find . -type f -name "*.so")
		$STRIP --strip-unneeded $SO_FILES
	fi
}

clean(){
	if [ $CLEANBUILDDIR == 'ON' ]; then
		git clean -xdf
	fi
}

build_with_cmake() {
        cp ${BUILD_ROOT}/android_cmake.sh .
        echo "$CURRENT_BUILD - $(git rev-parse --short HEAD)" >> $BUILD_STATUS_FILE
        rm -rf $BUILD_FOLDER
        mkdir -p $BUILD_FOLDER
        echo $PWD
        ./android_cmake.sh $@ -DCMAKE_VERBOSE_MAKEFILE=ON .
        pushd $BUILD_FOLDER
        make -j$JOBS
	strip
        make -j$JOBS install
	popd

	if [ $CLEANBUILDDIR == 'ON' ]; then
		rm -rf $BUILD_FOLDER
	fi

}

android_configure() {
        cp ${BUILD_ROOT}/android_configure.sh .
        echo "$CURRENT_BUILD - $(git rev-parse --short HEAD)" >> $BUILD_STATUS_FILE
        ./android_configure.sh $@

	if [ "$CURRENT_BUILD" = "gettext" ]; then
		autoreconf
	fi

	strip
        make -j$JOBS LDFLAGS="$LDFLAGS"
        make -j$JOBS install

        LDFLAGS="$LDFLAGS_COMMON"
	clean
}

#############################################################
### BOOST
#############################################################

build_boost() {

## ADI COMMENT PULL LATEST

pushd ${BUILD_ROOT}/Boost-for-Android
git clean -xdf
export CURRENT_BUILD=boost-for-android

strip
./build-android.sh --boost=1.82.0 --layout=system --toolchain=llvm --prefix=${PREFIX} --arch=$ABI --target-version=${API} ${ANDROID_NDK_ROOT}
popd
}

move_boost_libs() {
	cp -R $DEV_PREFIX/$ABI/* $DEV_PREFIX
}

#############################################################
### ZEROMQ
#############################################################

build_libzmq() {
pushd ${BUILD_ROOT}/libzmq
git clean -xdf
export CURRENT_BUILD=libzmq

./autogen.sh
./configure --enable-shared --disable-static --build=x86_64-unknown-linux-gnu --host=$TARGET_PREFIX$API --prefix=${PREFIX} LDFLAGS="-L${PREFIX}/lib" CPPFLAGS="-fPIC -I${PREFIX}/include"

make -j ${JOBS}
strip
make install
clean

# CXX Header-Only Bindings
wget -O $PREFIX/include/zmq.hpp https://raw.githubusercontent.com/zeromq/cppzmq/master/zmq.hpp
popd
}

#############################################################
### FFTW
#############################################################
build_fftw() {
## ADI COMMENT: USE downloaded version instead (OCAML fail?)
pushd ${BUILD_ROOT}/fftw
#wget http://www.fftw.org/fftw-3.3.9.tar.gz
# rm -rf fftw-3.3.9
# tar xvf fftw-3.3.9.tar.gz
git clean -xdf
export CURRENT_BUILD=fftw

if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "arm64-v8a" ]; then
	NEON_FLAG=--enable-neon
else
	NEON_FLAG=""
fi
echo $NEON_FLAG


./bootstrap.sh --enable-single --enable-static --enable-threads \
  --enable-float  $NEON_FLAG --disable-doc \
  --host=$TARGET_BINUTILS \
  --prefix=$PREFIX

make -j ${JOBS}
strip
make install
clean

popd
}

#############################################################
### OPENSSL
#############################################################
build_openssl() {
pushd ${BUILD_ROOT}/openssl
git clean -xdf
export CURRENT_BUILD=openssl

export ANDROID_NDK_HOME=${ANDROID_NDK_ROOT}

./Configure android-arm -D__ARM_MAX_ARCH__=7 --prefix=${PREFIX} shared no-ssl3 no-comp
make -j ${JOBS}
make install
popd
}

#############################################################
### THRIFT
#############################################################
build_thrift() {
pushd ${BUILD_ROOT}/thrift
git clean -xdf
export CURRENT_BUILD=thrift
rm -rf ${PREFIX}/include/thrift

./bootstrap.sh

CPPFLAGS="-I${PREFIX}/include" \
CFLAGS="-fPIC" \
CXXFLAGS="-fPIC" \
LDFLAGS="-L${PREFIX}/lib" \
./configure --prefix=${PREFIX}   --disable-tests --disable-tutorial --with-cpp \
 --without-python --without-qt4 --without-qt5 --without-py3 --without-go --without-nodejs --without-c_glib --without-php --without-csharp --without-java \
 --without-libevent --without-zlib \
 --with-boost=${PREFIX} --host=$TARGET_BINUTILS --build=x86_64-linux

sed -i '/malloc rpl_malloc/d' ./lib/cpp/src/thrift/config.h
sed -i '/realloc rpl_realloc/d' ./lib/cpp/src/thrift/config.h

make -j ${JOBS}
make install

sed -i '/malloc rpl_malloc/d' ${PREFIX}/include/thrift/config.h
sed -i '/realloc rpl_realloc/d' ${PREFIX}/include/thrift/config.h
popd
}

#############################################################
### GMP
#############################################################
build_libgmp() {
pushd ${BUILD_ROOT}/libgmp
ABI_BACKUP=$ABI
ABI=""
git clean -xdf
export CURRENT_BUILD=libgmp

./.bootstrap
./configure --enable-maintainer-mode --prefix=${PREFIX} \
            --host=$TARGET_BINUTILS \
            --enable-cxx
make clean
make -j ${JOBS}
make install
ABI=$ABI_BACKUP
popd
}

#############################################################
### LIBUSB
#############################################################
build_libusb() {
pushd ${BUILD_ROOT}/libusb/android/jni
# WE NEED TO USE BetterAndroidSupport PR from libusb
# this will be merged to mainline soon
# https://github.com/libusb/libusb/pull/874

git clean -xdf
export CURRENT_BUILD=libusb

export NDK=${ANDROID_NDK_ROOT}
${NDK}/ndk-build clean
${NDK}/ndk-build -B -r -R

cp ${BUILD_ROOT}/libusb/android/libs/$ABI/* ${PREFIX}/lib
cp ${PREFIX}/lib/libusb1.0.so $PREFIX/lib/libusb-1.0.so # IDK why this happens (?)
cp ${BUILD_ROOT}/libusb/libusb/libusb.h ${PREFIX}/include
popd
}

#############################################################
### HACK RF
#############################################################
build_hackrf() {
pushd ${BUILD_ROOT}/hackrf/host/
git clean -xdf
export CURRENT_BUILD=hackrf

mkdir build
cd build

$CMAKE -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${JOBS}
make install
popd
}

# #############################################################
# ### VOLK
#############################################################
build_volk() {
pushd ${BUILD_ROOT}/volk
git clean -xdf
export CURRENT_BUILD=volk

mkdir build
cd build
$CMAKE -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_ARM_NEON=ON \
  -DANDROID_STL=c++_shared \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DENABLE_STATIC_LIBS=False \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  -DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS_COMMON" \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DVOLK_CPU_FEATURES=ON \
  ../
make -j ${JOBS}
make install
popd
}

#############################################################
### GNU Radio
#############################################################
build_gnuradio() {
pushd ${BUILD_ROOT}/gnuradio
git clean -xdf
export CURRENT_BUILD=gnuradio

mkdir build
cd build

echo "$LDFLAGS_COMMON"

$CMAKE -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_ARM_NEON=ON \
  -DANDROID_STL=c++_shared \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 \
  -DENABLE_INTERNAL_VOLK=OFF \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  -DENABLE_DOXYGEN=OFF \
  -DENABLE_SPHINX=OFF \
  -DENABLE_PYTHON=OFF \
  -DENABLE_TESTING=OFF \
  -DENABLE_GR_FEC=OFF \
  -DENABLE_GR_AUDIO=OFF \
  -DENABLE_GR_DTV=OFF \
  -DENABLE_GR_CHANNELS=OFF \
  -DENABLE_GR_VOCODER=OFF \
  -DENABLE_GR_TRELLIS=OFF \
  -DENABLE_GR_WAVELET=OFF \
  -DENABLE_GR_CTRLPORT=OFF \
  -DENABLE_CTRLPORT_THRIFT=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS" \
  -DCMAKE_CXX_FLAGS="$CPPFLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS_COMMON" \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
   ../
make -j ${JOBS}
make install
popd
}

#############################################################
### GR OSMOSDR
#############################################################
build_gr-osmosdr() {
pushd ${BUILD_ROOT}/gr-osmosdr
git clean -xdf
export CURRENT_BUILD=gr-osmosdr

mkdir build
cd build

$CMAKE -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DBOOST_ROOT=${PREFIX} \
  -DANDROID_STL=c++_shared \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/$ABI/lib/cmake/gnuradio \
  -DENABLE_REDPITAYA=OFF \
  -DENABLE_RFSPACE=OFF \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../
make -j ${JOBS}
make install
popd
}

#############################################################
### GR GRAND
#############################################################
build_gr-grand() {
pushd ${BUILD_ROOT}/gr-grand
git clean -xdf
export CURRENT_BUILD=gr-grand

mkdir build
cd build

$CMAKE -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DANDROID_STL=c++_shared \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/$ABI/lib/cmake/gnuradio \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
    ../

make -j ${JOBS}
make install
popd
}

#############################################################
### GR SCHED
#############################################################
build_gr-sched() {
pushd ${BUILD_ROOT}/gr-sched
git clean -xdf
export CURRENT_BUILD=gr-sched

mkdir build
cd build

$CMAKE -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_BUILD_TYPE=$BUILD_TYPE \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=$ABI -DANDROID_ARM_NEON=ON \
  -DANDROID_STL=c++_shared \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_ARCHITECTURE=-a32 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/$ABI/lib/cmake/gnuradio \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${JOBS}
make install
popd
}


#############################################################
### LIBXML2
#############################################################
build_libxml2 () {
        pushd ${BUILD_ROOT}/libxml2
        git clean -xdf
        export CURRENT_BUILD=libxml2

	build_with_cmake -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_ZLIB=OFF

        popd
}

#############################################################
### LIBIIO
#############################################################
build_libiio () {
        pushd ${BUILD_ROOT}/libiio
        git clean -xdf
        export CURRENT_BUILD=libiio

	build_with_cmake -DHAVE_DNS_SD=OFF

        popd
}

#############################################################
### LIBAD9361
#############################################################
build_libad9361 () {
        pushd ${BUILD_ROOT}/libad9361-iio
        git clean -xdf
        export CURRENT_BUILD=libad9361-iio

	build_with_cmake

        popd
}

#############################################################
### GR IIO
#############################################################
build_gr-iio () {
        pushd ${BUILD_ROOT}/gr-iio
        git clean -xdf
        export CURRENT_BUILD=gr-iio

	build_with_cmake -DWITH_PYTHON=OFF

        popd
}

#############################################################
### LIBICONV
#############################################################
build_libiconv () {

        pushd ${BUILD_ROOT}/libiconv
	git clean -xdf
        export CURRENT_BUILD=libiconv

        LDFLAGS="$LDFLAGS_COMMON"
        android_configure --enable-static=no --enable-shared=yes

        popd
}

#############################################################
### LIBFFI
#############################################################
build_libffi() {
        pushd ${BUILD_ROOT}/libffi
        git clean -xdf
        export CURRENT_BUILD=libffi

#        ./autogen.sh
        LDFLAGS="$LDFLAGS_COMMON"
        android_configure --disable-docs --cache-file=android.cache --disable-multi-os-directory

        popd
}

#############################################################
### GETTEXT
#############################################################
build_gettext() {
        pushd ${BUILD_ROOT}/gettext
        git clean -xdf
        export CURRENT_BUILD=gettext

        LDFLAGS="$LDFLAGS_COMMON"
#	NOCONFIGURE=yes ./autogen.sh
        android_configure --cache-file=android.cache

        popd
}

#############################################################
### UHD
#############################################################
build_uhd() {
cd ${BUILD_ROOT}/uhd/host
git clean -xdf
export CURRENT_BUILD=uhd

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API} \
  -DANDROID_STL=c++_shared \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_DEBUG=OFF \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_USE_DEBUG_LIBS=OFF \
  -DBoost_ARCHITECTURE=-a64 \
  -DENABLE_STATIC_LIBS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_UTILS=OFF \
  -DENABLE_PYTHON_API=OFF \
  -DENABLE_MANUAL=OFF \
  -DENABLE_DOXYGEN=OFF \
  -DENABLE_MAN_PAGES=OFF \
  -DENABLE_OCTOCLOCK=OFF \
  -DENABLE_E300=OFF \
  -DENABLE_E320=OFF \
  -DENABLE_N300=OFF \
  -DENABLE_N320=OFF \
  -DENABLE_X300=OFF \
  -DENABLE_USRP2=OFF \
  -DENABLE_N230=OFF \
  -DENABLE_MPMD=OFF \
  -DENABLE_B100=OFF \
  -DENABLE_USRP1=OFF \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../
make -j ${NCORES}
make install
}

#############################################################
### RTL SDR
#############################################################
build_rtl-sdr() {
cd ${BUILD_ROOT}/rtl-sdr
git clean -xdf
export CURRENT_BUILD=rtl-sdr

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DANDROID_STL=c++_shared \
  -DDETACH_KERNEL_DRIVER=ON \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${NCORES}
make install
}


#############################################################
### GR IEEE 802.15.4
#############################################################
build_gr-ieee-802-15-4() {
cd ${BUILD_ROOT}/gr-ieee802-15-4
git clean -xdf
export CURRENT_BUILD=gr-ieee-802-15-4

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DANDROID_STL=c++_shared \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_DEBUG=OFF \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_USE_DEBUG_LIBS=OFF \
  -DBoost_ARCHITECTURE=-a64 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/arm64-v8a/lib/cmake/gnuradio \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${NCORES}
make install
}

#############################################################
### GR IEEE 802.11
#############################################################
build_gr-ieee-802-11() {
cd ${BUILD_ROOT}/gr-ieee802-11
git clean -xdf
export CURRENT_BUILD=gr-ieee802-11

mkdir build
cd build

cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a -DANDROID_ARM_NEON=ON \
  -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
  -DANDROID_STL=c++_shared \
  -DBOOST_ROOT=${PREFIX} \
  -DBoost_DEBUG=OFF \
  -DBoost_COMPILER=-clang \
  -DBoost_USE_STATIC_LIBS=ON \
  -DBoost_USE_DEBUG_LIBS=OFF \
  -DBoost_ARCHITECTURE=-a64 \
  -DGnuradio_DIR=${BUILD_ROOT}/toolchain/arm64-v8a/lib/cmake/gnuradio \
  -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
  ../

make -j ${NCORES}
make install
}

# #############################################################
# ### GR CLENABLED
# #############################################################
build_gr-clenabled() {
 cd ${BUILD_ROOT}/gr-clenabled
 git clean -xdf
 export CURRENT_BUILD=gr-clenabled

 mkdir build
 cd build

 cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} \
   -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake \
   -DANDROID_ABI=arm64-v8a -DANDROID_ARM_NEON=ON \
   -DANDROID_NATIVE_API_LEVEL=${API_LEVEL} \
   -DANDROID_STL=c++_shared \
   -DBOOST_ROOT=${PREFIX} \
   -DBoost_DEBUG=OFF \
   -DBoost_COMPILER=-clang \
   -DBoost_USE_STATIC_LIBS=ON \
   -DBoost_USE_DEBUG_LIBS=OFF \
   -DBoost_ARCHITECTURE=-a64 \
   -DGnuradio_DIR=${BUILD_ROOT}/toolchain/arm64-v8a/lib/cmake/gnuradio \
   -DCMAKE_FIND_ROOT_PATH=${PREFIX} \
   ../

 make -j ${NCORES}
 make install


}
