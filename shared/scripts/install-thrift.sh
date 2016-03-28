#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Siemens AG, 2013-2015. Part of the SW360 Portal Project.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# script automatically generating keys for password-free login onto 
# the vagrantbox
#
#
# initial author: birgit.heydenreich@tngtech.com
# 
# -----------------------------------------------------------------------------

set -e
echo "-[shell provisioning] Installing dependencies of thrift"
apt-get update
apt-get install -y libboost-dev libboost-test-dev libboost-program-options-dev libevent-dev automake libtool flex bison pkg-config g++ libssl-dev 


echo "-[shell provisioning] Extracting thrift"
tar -xzf /vagrant_shared/packages/thrift-0.9.3.tar.gz -C /tmp/

pushd /tmp/thrift-0.9.3/ &>/dev/null


echo "-[shell provisioning] Building and installing thrift"
./configure --without-test --without-erlang --without-python --without-cpp --without-java --without-php
make 
make install
rm -rf /tmp/thrift-0.9.3/

popd &>/dev/null
