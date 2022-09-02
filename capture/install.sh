# !!! Don't execute this script directly !!!
# It is imported in $TOP/install.sh

export LANG=en_US.utf8 \
    SMCROUTE_VERSION=2.4.3

source $TOP_DIR/capture/dpdk/install.sh

install_mellanox()
{
    apt install -y rdma-core libibverbs-dev mft
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
