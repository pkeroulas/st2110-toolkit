# !!! Don't execute this script directly !!!
# It is imported in $TOP/install.sh

export LANG=en_US.utf8 \
    SMCROUTE_VERSION=2.4.3

source $TOP_DIR/capture/dpdk/install.sh

install_mellanox()
{
    echo "Installing Mellanox libs"

    apt install -y rdma-core libibverbs-dev

    # MFT: Mellanox Firmware Tools
    # https://network.nvidia.com/products/adapter-software/firmware-tools/
    # It includes mst utility but it turns out it is not necessaery for
    # capture
    #
    # install:
    # apt install -y dkms
    # DIR=$(mktemp -d)
    # cd $DIR/
    # wget http://www.mellanox.com/downloads/MFT/mft-4.5.0-31-x86_64-rpm.tgz
    # tar xzvf mft-4.5.0-31-x86_64-rpm.tgz
    # cd mft-4.5.0-31-x86_64-rpm
    # ./install.sh
    # rm -rf $DIR
}

install_smcroute()
{
    echo "Installing smcroute"
    DIR=$(mktemp -d)
    cd $DIR/
    wget https://github.com/troglobit/smcroute/releases/download/2.4.3/smcroute-$SMCROUTE_VERSION.tar.gz
    tar xaf smcroute-$SMCROUTE_VERSION.tar.gz
    cd smcroute-$SMCROUTE_VERSION
    ./autogen.sh
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
    make
    make install
    make distclean
    rm -rf $DIR

    bin=$(readlink -f $(which smcroutectl))
    chgrp pcap $bin
    setcap cap_net_raw,cap_net_admin=eip $bin
}

install_capture()
{
    install_mellanox
    install_dpdk
    install_smcroute
}
