# !!! Don't execute this script directly !!!
# It is imported in $TOP/install.sh

export LANG=en_US.utf8 \
    PTP_VERSION=2.0 \
    SMCROUTE_VERSION=2.4.3

install_ptp()
{
    # build+patch linuxptp instead of installing pre-built package
    cd $THIS_DIR
    dir=$(pwd)
    echo "Installing PTP"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone http://git.code.sf.net/p/linuxptp/code linuxptp
    cd linuxptp
    git checkout -b $PTP_VERSION v$PTP_VERSION
    patch -p1 < $dir/ptp/0001-port-do-not-answer-in-case-of-unknown-mgt-message-co.patch
    make
    make install
    make distclean
    rm -rf $DIR

    install -m 644 $THIS_DIR/ptp/ptp4l.conf     /etc/linuxptp/ptp4l.conf
}

install_mellanox()
{
    iso_file="$1"
    if [ ! -f $iso_file ]; then
        echo "Couldn't find $iso_file.
Manually fetch it from:
https://docs.mellanox.com/display/MLNXOFEDv461000/Downloading+Mellanox+OFED"
        return 1
    fi

    mkdir -p /mnt/iso
    mount -o loop $iso_file /mnt/iso
    /mnt/iso/mlnxofedinstall --with-vma --force-fw-update
    # if dkms fails to build :
    #/mnt/iso/mlnxofedinstall --with-vma --force-fw-update --without-dkms --add-kernel-support
    echo "Installed libs:"
    find /usr -name "*libvma*" -o -name "*libmlx5*" -o -name "*libibverbs*"

    echo "Start Mellanox stuff:"
    /etc/init.d/openibd restart
    ibv_devinfo
    mst start
    mlxfwmanager
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

install_dpdk()
{
    # sudo apt install rdma-core libibverbs-dev libpcap-dev
    echo "Installing dpdk"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://github.com/pkeroulas/dpdk.git
    cd dpdk
    make defconfig
    sed -i 's/MLX5_PMD=.*/MLX5_PMD=y/' ./build/.config
    sed -i 's/MLX5_DEBUG=.*/MLX5_DEBUG=y/' ./build/.config
    sed -i 's/PMD_PCAP=.*/PMD_PCAP=y/' ./build/.config
    make -j6
    make install
}

install_capture()
{
    install_ptp
    install_mellanox
    install_smcroute
    install_dpdk
}
