install_dpdk()
{
    install -m 755 ./dpdk-capture.sh /usr/sbin/

    echo "Installing dpdk"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://github.com/pkeroulas/dpdk.git
    cd dpdk
    git checkout -b clock_info origin/pdump_mlx5_hw_ts/clock_info/v2

    meson setup build
    cd build
    ninja
    ninja install

    rm $DIR

    for p in testpmd dpdk-pdump smcroutectl; do
        bin=$(readlink -f $(which $p))
        chgrp pcap $bin
        setcap cap_net_raw,cap_net_admin=eip $bin
    done
}
