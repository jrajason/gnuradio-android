#docker build -t analogdevices/scopy-build:android --build-arg QT_USER=<your_user> --build-arg QT_PASSWORD=<your_password> .
FROM ubuntu:20.04
SHELL ["/bin/bash", "-c"]

ARG USER=analog

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y mlocate git git-gui vim wget unzip sudo xserver-xorg openjdk-11-jre cmake libtool build-essential pkg-config autogen bison flex texinfo python-dev python-mako python-six swig3.0 python3-mako python3-numpy gettext libglib2.0-dev texinfo subversion libxkbcommon-x11-0 libxcb-xinerama0 libqt5gui5 libncurses5 autoconf-archive mm-common python3-pip


RUN groupadd -g 1000 -r $USER
RUN useradd -u 1000 -g 1000 --create-home -r $USER

#Change password
RUN echo "$USER:$USER" | chpasswd

#Make sudo passwordless
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER
RUN usermod -aG plugdev $USER

USER $USER

RUN mkdir -p /home/$USER/src
WORKDIR /home/$USER/src

#install cmake
RUN cd /home/$USER && wget https://github.com/Kitware/CMake/releases/download/v3.23.2/cmake-3.23.2-linux-x86_64.tar.gz && tar xvf cmake-3.23.2-linux-x86_64.tar.gz

#install Android SDK and NDK
WORKDIR /home/$USER/src
RUN wget https://dl.google.com/android/repository/commandlinetools-linux-6200805_latest.zip
RUN unzip commandlinetools-linux-6200805_latest.zip

RUN mkdir -p /home/$USER/Android/Sdk
ENV ANDROID_HOME /home/$USER/Android/Sdk
WORKDIR /home/$USER/src/tools/bin

RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} --licenses
RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} "platforms;android-28"
RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} "ndk;23.1.7779620"
RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} "platform-tools"
RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} "build-tools;28.0.3"
RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} "build-tools;30.0.3"
RUN yes | ./sdkmanager --sdk_root=${ANDROID_HOME} "cmdline-tools;latest"

RUN sudo ln -s /home/$USER/Android/Sdk/platform-tools/adb /usr/local/bin/adb
RUN sudo python3 -m pip install -U pip

#install Qt
RUN pip3 install aqtinstall && /home/analog/.local/bin/aqt install-qt linux android 5.15.2 -O /home/$USER/Qt && /home/analog/.local/bin/aqt install-qt linux desktop 5.15.2 -O /home/$USER/Qt

#install JDK14
WORKDIR /home/$USER
RUN wget https://download.java.net/java/GA/jdk14.0.2/205943a0976c4ed48cb16f1043c5c647/12/GPL/openjdk-14.0.2_linux-x64_bin.tar.gz
RUN tar xvf openjdk-14.0.2_linux-x64_bin.tar.gz

# INSTALL QTCREATOR
RUN /home/analog/.local/bin/aqt install-tool linux desktop tools_qtcreator
RUN sudo ln -s /home/$USER/Tools/QtCreator/bin/qtcreator.sh /usr/local/bin/qtcreator

# build dependencies
WORKDIR /home/$USER/src
RUN git clone https://github.com/jrajason/gnuradio-android.git --branch gnuradio-3.10-android
WORKDIR /home/$USER/src/gnuradio-android
RUN ./init_env.sh
RUN ./build_python_modules.sh install_deps
RUN ./build_python_modules.sh build_python
RUN ./build_dependencies.sh first_stage

RUN ./build_python_modules.sh download_pyqt5
RUN ./build_python_modules.sh build_venv
RUN ./build_dependencies.sh second_stage


# INSTALL x86 GNURADIO
RUN ./build_gnuradio.sh install_deps
RUN ./build_gnuradio.sh build_deps
RUN ./build_gnuradio.sh build_gr

RUN sudo ldconfig
#build deps finished

#patch strip - an incompatibility between gradle and ndk strip version - HACK -> rename a compatible strip so gradle uses that one
WORKDIR /home/$USER/src/gnuradio-android/
RUN ./toolchain_patches.sh create_strip_symlink

#RUN echo 23 && git fetch && git reset origin/gnuradio-3.10-android --hard#  && git submodule update gr-flowgraph-runner
# C++ example - build for x86
WORKDIR /home/$USER/src/gnuradio-android/GRCTestFlow/SignalLoopback
#build for x86
RUN mkdir build_x86-64 && cd build_x86-64 && cmake ../ && make 
#build for android
RUN pushd ../../ && \
ls && \
source ./android_toolchain.sh && \
popd && \
cp -R ../../android-app-helper/* . && \
./android_cmake.sh && \
cd build_aarch64-linux-android_api28_ndk23_Debug && \
make && \
cd .. && \
./android_deploy_libs.sh copy-all-libs-from-staging && \
./android_deploy_libs.sh copy-missing-qt-libs && \
./android_deploy_qt.sh apk

# Python gr-flowgraph-runner
WORKDIR /home/$USER/src/gnuradio-android/
WORKDIR /home/$USER/src/gnuradio-android/gr-flowgraph-runner
RUN pushd ../ && \
ls && \
source ./android_toolchain.sh && \
popd && \
echo !!! - gr flowgraphrunner already contains edited cmake and android script - do not copy  cp -R ../android-app-helper/* . && \
./android_cmake.sh && \
cd build_aarch64-linux-android_api28_ndk23_Debug && \
make && \
cd .. && \
./android_deploy_libs.sh copy-all-libs-from-staging && \
./android_deploy_libs.sh copy-missing-qt-libs && \
./android_deploy_libs.sh copy-python && \
./android_deploy_libs.sh remove-cache && \
echo !!! - remove echo to strip - not stripping is useful for debugging ./android_deploy_libs.sh strip-everything && \
./android_deploy_qt.sh apk

# after this a manual step is done where I configure QtCreator 
