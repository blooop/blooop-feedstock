#!/bin/bash
# Hybrid build: assumes OpenHaptics SDK is installed on the system
# (e.g., via Docker image with 3D Systems SDK at /usr/include/HD, /usr/lib/libHD.so)
set -eo pipefail

rm -rf build
mkdir build
cd build

export LINK=$CXX

PYTHON_EXECUTABLE=$PREFIX/bin/python
PKG_CONFIG_EXECUTABLE=$PREFIX/bin/pkg-config
OSX_DEPLOYMENT_TARGET="10.15"

echo "USING PYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}"
echo "USING PKG_CONFIG_EXECUTABLE=${PKG_CONFIG_EXECUTABLE}"

export ROS_PYTHON_VERSION=`$PYTHON_EXECUTABLE -c "import sys; print('%i.%i' % (sys.version_info[0:2]))"`
echo "Using Python ${ROS_PYTHON_VERSION}"

export PYTHON_INSTALL_DIR=`python -c "import os;print(os.path.relpath(os.environ['SP_DIR'],os.environ['PREFIX']))"`
echo "Using PYTHON_INSTALL_DIR: $PYTHON_INSTALL_DIR"

if [[ $target_platform =~ linux.* ]]; then
    export CFLAGS="${CFLAGS} -D__STDC_FORMAT_MACROS=1 -I/usr/include"
    export CXXFLAGS="${CXXFLAGS} -D__STDC_FORMAT_MACROS=1 -I/usr/include"
    ln -s $GCC ${BUILD_PREFIX}/bin/gcc
    ln -s $GXX ${BUILD_PREFIX}/bin/g++
fi

export SKIP_TESTING=ON

WORK_DIR=$SRC_DIR/$PKG_NAME/src/work/phantom_touch_control

cmake \
    -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_PREFIX_PATH="$PREFIX;/usr/local" \
    -DHD_INCLUDE_DIR=/usr/include/HD \
    -DHD_LIBRARY=/usr/lib/libHD.so \
    -DAMENT_PREFIX_PATH=$PREFIX \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DPYTHON_EXECUTABLE=$PYTHON_EXECUTABLE \
    -DPython_EXECUTABLE=$PYTHON_EXECUTABLE \
    -DPython3_EXECUTABLE=$PYTHON_EXECUTABLE \
    -DPython3_FIND_STRATEGY=LOCATION \
    -DPKG_CONFIG_EXECUTABLE=$PKG_CONFIG_EXECUTABLE \
    -DPYTHON_INSTALL_DIR=$PYTHON_INSTALL_DIR \
    -DSETUPTOOLS_DEB_LAYOUT=OFF \
    -DCATKIN_SKIP_TESTING=$SKIP_TESTING \
    -DCMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP=True \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=OFF \
    -DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local/homebrew" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=$OSX_DEPLOYMENT_TARGET \
    -DCMAKE_MODULE_PATH="$WORK_DIR/cmake/Modules" \
    --compile-no-warning-as-error \
    $WORK_DIR

cmake --build . --config Release --target install
