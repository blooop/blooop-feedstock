#!/bin/bash
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
    export CFLAGS="${CFLAGS} -D__STDC_FORMAT_MACROS=1 -I/usr/local/zed/include -I/usr/local/cuda/include"
    export CXXFLAGS="${CXXFLAGS} -D__STDC_FORMAT_MACROS=1 -I/usr/local/zed/include -I/usr/local/cuda/include"
    export LDFLAGS="${LDFLAGS} -L/usr/local/zed/lib -L/usr/local/cuda/lib64"
    ln -s $GCC ${BUILD_PREFIX}/bin/gcc
    ln -s $GXX ${BUILD_PREFIX}/bin/g++
fi

export SKIP_TESTING=ON

WORK_DIR=$SRC_DIR/$PKG_NAME/src/work/zed_ros2

cmake \
    -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_PREFIX_PATH="$PREFIX;/usr/local/zed;/usr/local/cuda" \
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
    --compile-no-warning-as-error \
    $WORK_DIR

cmake --build . --config Release --target install
