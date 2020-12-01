#TODO remove driver (no need for hca_attr if clock_dev) + mst stuff
#but install rdma-core libibverbs

install_dpdk()
{
    apt install libnuma-dev libpcap-dev screen

    echo "Installing dpdk"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://github.com/pkeroulas/dpdk.git
    cd dpdk
    git checkout clock_info -b origin/pdump_mlx5_hw_ts/clock_info/v1

    make defconfig
    sed -i 's/MLX5_PMD=.*/MLX5_PMD=y/' ./build/.config
    sed -i 's/MLX5_DEBUG=.*/MLX5_DEBUG=y/' ./build/.config
    sed -i 's/PMD_PCAP=.*/PMD_PCAP=y/' ./build/.config

    MAKE_PAUSE=n make -j6
    make install


    install -m 755 ./dpdk-capture.sh /usr/sbin/

    for p in testpmd dpdk-pdump smcroutectl; do
        bin=$(readlink -f $(which $p))
        chgrp pcap $bin
        setcap cap_net_raw,cap_net_admin=eip $bin
    done
}
