#!/bin/bash
set -eo pipefail

WORK_DIR=$SRC_DIR/$PKG_NAME/src/work/phantom_touch_description
cd $WORK_DIR

$PREFIX/bin/python -m pip install . --no-deps --no-build-isolation --prefix=$PREFIX

# Install ROS package metadata
mkdir -p $PREFIX/share/ament_index/resource_index/packages
touch $PREFIX/share/ament_index/resource_index/packages/phantom_touch_description
mkdir -p $PREFIX/share/phantom_touch_description
cp package.xml $PREFIX/share/phantom_touch_description/

# Install data directories
if [ -d "urdf" ]; then
    cp -r urdf $PREFIX/share/phantom_touch_description/
fi
if [ -d "meshes" ]; then
    cp -r meshes $PREFIX/share/phantom_touch_description/
fi
if [ -d "launch" ]; then
    cp -r launch $PREFIX/share/phantom_touch_description/
fi
