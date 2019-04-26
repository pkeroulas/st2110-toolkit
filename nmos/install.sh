#imported from $TOP/install.sh

export CMAKE_VERSION=3.11.2 \
    BOOST_VERSION=1.67.0 \
    MDNS_VERSION=878.30.4 \
    REST_VERSION=2.10.11

install_cmake()
{
    echo "Installing CMake"
    DIR=$(mktemp -d)
    cd $DIR/
    wget --no-check-certificate https://cmake.org/files/v3.11/cmake-$CMAKE_VERSION.tar.gz
    tar xvf cmake-$CMAKE_VERSION.tar.gz
    cd $DIR/cmake-$CMAKE_VERSION
    ./bootstrap
    make
    make install
    rm -rf $DIR
}

install_boost()
{
    echo "Installing Boost"
    DIR=$(mktemp -d)
    cd $DIR/
    boost_version=$(echo $BOOST_VERSION | tr '.' '_')
    wget --no-check-certificate https://dl.bintray.com/boostorg/release/$BOOST_VERSION/source/boost_$boost_version.tar.gz
    tar xvf boost_$boost_version.tar.gz
    cd $DIR/boost_$boost_version
    ./bootstrap.sh --with-libraries=date_time,regex,system,thread,random,filesystem,chrono,atomic --prefix=$PREFIX
    ./b2 install
    rm -rf $DIR
}

install_mdns(){
    ## You should use either Avahi or Apple mDNS - DO NOT use both
    echo "Installing mDNSResponder"
    wget --no-check-certificate https://opensource.apple.com/tarballs/mDNSResponder/mDNSResponder-$MDNS_VERSION.tar.gz
    tar xvf mDNSResponder-$MDNS_VERSION.tar.gz

    wget https://raw.githubusercontent.com/sony/nmos-cpp/master/Development/third_party/mDNSResponder/poll-rather-than-select.patch
    patch -d mDNSResponder-$MDNS_VERSION/ -p1 < poll-rather-than-select.patch

    cd ./mDNSResponder-$MDNS_VERSION/mDNSPosix
    set HAVE_IPV6=0
    #TODO: put that in $PREFIX
    make os=linux
    make os=linux install
    #rm -rf $DIR
}

install_cpprest()
{
    echo "Installing C++ REST"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone --recurse-submodules --branch v$REST_VERSION https://github.com/Microsoft/cpprestsdk
    mkdir cpprestsdk/Release/build
    cd cpprestsdk/Release/build

    cmake .. \
        -DCMAKE_BUILD_TYPE:STRING="Release" \
        -DWERROR:BOOL="0"
    make
    make install

    #TODO: figure out where this should be installed
    mkdir /root/cpprest
    cp -r ../libs /root/cpprest/

    rm -rf $DIR
}

install_cppnode()
{
    echo "Installing Sony nmos-cpp"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://github.com/sony/nmos-cpp.git
    mkdir ./nmos-cpp/Development/build
    cd ./nmos-cpp/Development/build

    cmake .. \
        -G "Unix Makefiles" \
        -DCMAKE_CONFIGURATION_TYPES:STRING="Debug" \
        -DBoost_USE_STATIC_LIBS:BOOL="1" \
        -DWEBSOCKETPP_INCLUDE_DIR:PATH="/root/cpprest/libs/websocketpp"

    make
    install -m 755 ./nmos-cpp-node ./nmos-cpp-registry ./nmos-cpp-test $PREFIX/bin
    rm -rf $DIR
}

install_nmos() {
    install_cmake
    install_boost
    install_mdns
    install_cpprest
    install_cppnode
}
