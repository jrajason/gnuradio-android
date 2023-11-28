#!/bin/bash

############### SYSTEM SPECIFIC DEFINES ############
export USER_DIR=$USER
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export CMAKE=$HOME/cmake-3.23.2-linux-x86_64/bin/cmake
export QT_VERSION_STRING=5.15.2
export QT_HOME=$HOME/Qt
export QT_INSTALL_PREFIX_NO_POSTFIX=${QT_HOME}/${QT_VERSION_STRING}/android
export JDK=$HOME/jdk-14.0.2
export JAVA_HOME=$JDK
export PATH=$JAVA_HOME/bin:$PATH
export PYTHON_VERSION=3.8.10
export GR4A_SCRIPT_DIR=$HOME/src/scopy-android-deps/gnuradio-android
export DEPS_SRC_PATH=$GR4A_SCRIPT_DIR/downloads
#export BUILD_TYPE=Release
export BUILD_TYPE=Debug
#export BUILD_TYPE=RelWithDebInfo
export NDK_VERSION=23.1.7779620
#export NDK_VERSION=21.3.6528147
export API=28 # need ABI at least 28 for glob from my tests
export JOBS=16
export HOST_ARCH=linux-x86_64
export ANDROID_SDK_BUILD_TOOLS=30.0.2
export ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/$NDK_VERSION
export PYTHON_VERSION_MINOR=8

export PYTHON_VERSION=3.$PYTHON_VERSION_MINOR
export LD_LIBRARY_PATH=$GR4A_SCRIPT_DIR/build-python/lib

export APP_PLATFORM=${API}
#export JOBS=$(getconf _NPROCESSORS_ONLN)

if [ -z "$ARCH" ]; then
	ARG1=aarch64
else
	ARG1=$ARCH
fi

TARGET_PREFIX=NO_ABI
export QT_INSTALL_PREFIX=${QT_INSTALL_PREFIX_NO_POSTFIX}


if [ $ARG1 = "aarch64" ]; then
############ aarch64 #########
export ABI=arm64-v8a
export ABI_BITS=64
export TARGET_PREFIX=aarch64-linux-android
export TARGET_BINUTILS=aarch64-linux-android
export QT_MAJOR_VERSION=${QT_VERSION_STRING:0:1}
if [ ${QT_MAJOR_VERSION} -eq 6 ]; then
	export QT_INSTALL_PREFIX=${QT_INSTALL_PREFIX}_arm64_v8a
	export CMAKE_TOOLCHAIN_FILE=$QT_INSTALL_PREFIX/lib/cmake/Qt${QT_MAJOR_VERSION}/qt.toolchain.cmake
else
	export CMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake

fi
#############################
fi

if [ $ARG1 = "arm" ]; then
############# armv7a ##########
export ABI=armeabi-v7a
export ABI_BITS=32
export TARGET_PREFIX=armv7a-linux-androideabi
export TARGET_BINUTILS=arm-linux-androideabi
if [ ${QT_MAJOR_VERSION} -eq 6 ]; then
	export QT_INSTALL_PREFIX=${QT_INSTALL_PREFIX}_armv7
	export CMAKE_TOOLCHAIN_FILE=$QT_INSTALL_PREFIX/lib/cmake/Qt${QT_MAJOR_VERSION}/qt.toolchain.cmake
else
	export CMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake

fi
###############################
fi

if [ $ARG1 = "x86_64" ]; then
############# x86_64 ###########
export TARGET_BINUTILS=x86_64-linux-android
export ABI=x86_64
export TARGET_PREFIX=x86_64-linux-android
if [ ${QT_MAJOR_VERSION}  -eq 6 ]; then
	export QT_INSTALL_PREFIX=${QT_INSTALL_PREFIX}_x86_64
	export CMAKE_TOOLCHAIN_FILE=$QT_INSTALL_PREFIX/lib/cmake/Qt6/qt.toolchain.cmake
else
	export CMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake

fi
#################################
fi

if [ $ARG1 = "x86" ]; then
######## x86 - i686 ############
export TARGET_PREFIX=i686-linux-android
export ABI=x86
export TARGET_BINUTILS=i686-linux-android
if [ ${QT_MAJOR_VERSION}  -eq 6 ]; then
	export QT_INSTALL_PREFIX=${QT_INSTALL_PREFIX}_x86
	export CMAKE_TOOLCHAIN_FILE=$QT_INSTALL_PREFIX/lib/cmake/Qt6/qt.toolchain.cmake
else
	export CMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake

fi
#################################
fi

export TARGET=${TARGET_PREFIX}
export BUILDDIR=build_${TARGET_PREFIX}_api${API}_ndk${NDK_VERSION:0:2}_${BUILD_TYPE}
export WORKDIR=$GR4A_SCRIPT_DIR/$BUILDDIR

# This is just an empty directory where I want the built objects to be installed
export DEV_PREFIX=$WORKDIR/out
export TOOLCHAIN=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/$HOST_ARCH
export TOOLCHAIN_BIN=${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_ARCH}/bin
export QMAKE=$QT_INSTALL_PREFIX/bin/qmake
export ANDROID_QT_DEPLOY=$QT_INSTALL_PREFIX/bin/androiddeployqt
export BUILD_STATUS_FILE=$WORKDIR/build-status
