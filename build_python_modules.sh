#!/bin/bash
source build_system_setup.sh

set -x
set -e 

build_python() {
	pushd build-python-src
	git clean -xdf
	./configure --disable-ipv6 --enable-optimizations --with-ensurepip=install --enable-shared --prefix="$GR4A_SCRIPT_DIR/build-python"
	make -j $JOBS
	make install
	ln -s $GR4A_SCRIPT_DIR/build-python/bin/pip3 $GR4A_SCRIPT_DIR/build-python/bin/pip
	popd
}

create_venv() {
	pushd $GR4A_SCRIPT_DIR

	export PATH=${GR4A_SCRIPT_DIR}/build-python/bin:$PATH
	export LD_LIBRARY_PATH=$GR4A_SCRIPT_DIR/build-python/lib:$LD_LIBRARY_PATH
	
	pip install crossenv

	if [ ! -d venv ]; then
		./build-python/bin/python3 -m crossenv $DEV_PREFIX/bin/python$PYTHON_VERSION venv
	fi

	. $GR4A_SCRIPT_DIR/venv/bin/activate
	build-pip install setuptools --upgrade
	build-pip install numpy==1.17.4 # install python only on build-pip so crosscompile checks for numpy pass
#	cross-pip install numpy==1.17.4 
	build-pip install pytest
	cross-pip install pytest
#	build-pip install pybind11
#	cross-pip install pybind11==2.4.3
	build-pip install packaging
	cross-pip install packaging
	build-pip install cython==0.28.5
	cross-pip install cython==0.28.5
	build-pip install mako==1.1.0
	cross-pip install mako==1.1.0
	build-pip install sip
	cross-pip install sip
	build-pip install pyqt-builder
	cross-pip install pyqt-builder #need this ?
	
	build-pip install pyqt5-sip
	cross-pip install pyqt5-sip

	rm -rf venv/cross/bin/sip-*
	cp venv/build/bin/sip-* venv/cross/bin/
	#patch sip-build -- change shebang from build to cross
	sed -i '0,/build/s/build/cross/' venv/cross/bin/sip-*

	popd
}

download_pyqt5() {
	pushd $GR4A_SCRIPT_DIR

	wget https://files.pythonhosted.org/packages/39/5f/fd9384fdcb9cd0388088899c110838007f49f5da1dd1ef6749bfb728a5da/PyQt5_sip-12.11.0.tar.gz
	wget https://files.pythonhosted.org/packages/e1/57/2023316578646e1adab903caab714708422f83a57f97eb34a5d13510f4e1/PyQt5-5.15.7.tar.gz
	tar xvf PyQt5_sip-12.11.0.tar.gz
	tar xvf PyQt5-5.15.7.tar.gz
}

build_pyqt5-sip() {
	pushd $GR4A_SCRIPT_DIR
	. $GR4A_SCRIPT_DIR/venv/bin/activate
	
	source android_toolchain.sh	
	popd
	pushd $GR4A_SCRIPT_DIR/PyQt5_sip-12.11.0
	rm -rf build
	LDFLAGS='-lpython3' cross-python setup.py bdist
	
	#hack as i don't know how to disable egg install
	mkdir -p /home/$USER/src/scopy-android-deps/gnuradio-android/venv/cross/lib/python$PYTHON_VERSION/PyQt5/
	cp build/lib.linux-aarch64-cpython-3$PYTHON_VERSION_MINOR/PyQt5/sip.cpython-3$PYTHON_VERSION_MINOR.so $GR4A_SCRIPT_DIR/venv/cross/lib/python3.$PYTHON_VERSION_MINOR/PyQt5/
	popd
}

build_pybind11() {
	. $GR4A_SCRIPT_DIR/venv/bin/activate
	pushd $GR4A_SCRIPT_DIR/pybind11
	cross-python setup.py build
	popd
	

}

build_pyqt5() {
	pushd $GR4A_SCRIPT_DIR
	source android_toolchain.sh	
	popd
	pushd $GR4A_SCRIPT_DIR/PyQt5-5.15.7
	ANDROID_NDK_PLATFORM=android-30\
		/home/$USER/src/scopy-android-deps/gnuradio-android/venv/cross/bin/sip-build\
	       	--confirm-license\
	       	--jobs $JOBS\
	       	--no-tools\
	       	--no-dbus-python --no-qml-plugin\
	       	--no-designer-plugin\
	       	--target-dir ${DEV_PREFIX}/lib/python$PYTHON_VERSION\
	       	--build-dir ./build\
	       	--qmake=$QMAKE\
		--qmake-setting ANDROID_NDK_PLATFORM=android-30\
		--qmake-setting ANDROID_PLATFORM=android-30\
	       	--qmake-setting ANDROID_ABIS=arm64-v8a\
	       	--qmake-setting QMAKE_LFLAGS="-L$DEV_PREFIX/lib -lpython$PYTHON_VERSION"\
	       	--verbose\
	       	--no-make\
	       	--qt-shared\
	       	--android-abi arm64-v8a\
		--protected-is-public\
		--enable Qt\
	       	--enable QtCore \
		--enable QtGui \
		--enable QtNetwork \
		--enable QtWidgets  \
		--enable QtAndroidExtras\
		--disabled-feature PyQt_Desktop_OpenGL\
		--disabled-feature PyQt_Printer
		#--enable _QOpenGLFunctions_ES2\
		#--enable QtOpenGL\

	cd build
	make -j16
	make install
	popd
}

build_numpy() {
	pushd $GR4A_SCRIPT_DIR
	source android_toolchain.sh	
	popd
	pushd $GR4A_SCRIPT_DIR/numpy
	git clean -xdf
	LDFLAGS='-lpython3' MATHLIB=m cross-python setup.py build
	cross-python setup.py install

	# not sure if this is needed here
	mkdir -p $GR4A_SCRIPT_DIR/venv/cross/lib/python3.$PYTHON_VERSION_MINOR/site-packages
	cp -R build/lib.linux-aarch64-cpython-3$PYTHON_VERSION_MINOR/numpy* $GR4A_SCRIPT_DIR/venv/cross/lib/python3.$PYTHON_VERSION_MINOR/site-packages

#	build-pip install numpy==1.22.4
}

install_deps() {
	sudo apt-get install -y build-essential zlib1g-dev libbz2-dev liblzma-dev libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev libgdbm-dev liblzma-dev tk8.6-dev lzma lzma-dev libgdbm-dev
}
install_venv () {
	pushd $GR4A_SCRIPT_DIR
	source android_toolchain.sh
	cp -R $GR4A_SCRIPT_DIR/venv/cross/lib/* $DEV_PREFIX/lib
	popd
}

build_venv() {
	create_venv
	build_numpy
#	build-pybind11
	build_pyqt5-sip
	build_pyqt5
	install_venv
}

export LD_LIBRARY_PATH=$GR4A_SCRIPT_DIR/build-python/lib
#install_deps
#build_python
#create_venv
#build_numpy
#build_pyqt5-sip
#build_pyqt5
#install_venv
$@
