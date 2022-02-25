#!/bin/bash
#
# Compile & Install everything for FFMPEG transcoding
# and tcpdump capturing and EBU-LIST

#set -euo pipefail

TOP_DIR=$(dirname $(readlink -f $0))

ST2110_CONF_FILE=/etc/st2110.conf

if [ -f /etc/lsb-release ]; then
    OS=debian
    PACKAGE_MANAGER=apt
elif [ -f /etc/redhat-release ]; then
    OS=redhat
    PACKAGE_MANAGER=yum
else
    echo "Couldn't detect OS."
    exit 1
fi

export LANG=en_US.utf8 \
    LC_ALL=en_US.utf8 \
    PREFIX=/usr/local \

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig \

echo "${PREFIX}/lib" >/etc/ld.so.conf.d/libc.conf

source $TOP_DIR/capture/install.sh
source $TOP_DIR/ebu-list/install.sh
source $TOP_DIR/nmos/install.sh
source $TOP_DIR/transcoder/install.sh
source $TOP_DIR/ptp/install.sh

install_common_tools()
{
    $PACKAGE_MANAGER -y update && $PACKAGE_MANAGER install -y \
        autoconf \
        automake \
        bzip2 \
        cmake \
        lldpd \
        ethtool \
        gcc \
        git \
        libtool \
        make \
        net-tools \
        patch \
        perl \
        tar \
        tcpdump \
        tmux \
        wget \

    if [ $OS = "redhat" ]; then
        $PACKAGE_MANAGER -y update && $PACKAGE_MANAGER install -y \
            nc \
            gcc-c++ \
            openssl-devel \
            which \
            zlib-devel
    else
        $PACKAGE_MANAGER -y update && $PACKAGE_MANAGER install -y \
            libssl-dev \
            g++ \
            zlib1g-dev
    fi

    # rigth capabilities in order to use tcpdump, ip, iptables without sudo
    groupadd pcap
    for p in tcpdump ip iptables; do
        bin=$(readlink -f $(which $p))
        chgrp pcap $bin
        setcap cap_net_raw,cap_net_admin=eip $bin
    done
}

install_dev_tools()
{
    if [ $OS = "redhat" ]; then
        wget dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-11.noarch.rpm
        rpm -ihv epel-release-7-11.noarch.rpm
    fi

    $PACKAGE_MANAGER -y install \
        htop \
        nload \
        vim \
        tig \
        psmisc
}

install_config()
{
    if [ ! -f  $ST2110_CONF_FILE ]; then
        echo "Don't overwrite config, it is painful"
        install -m 644 $TOP_DIR/config/st2110.conf $ST2110_CONF_FILE
    else
        source $ST2110_CONF_FILE
    fi

    install -m 666 $TOP_DIR/config/st2110.bashrc /home/$ST2110_USER/
    if ! grep -q 2110 /home/$ST2110_USER/.bashrc; then
        echo "source /home/$ST2110_USER/st2110.bashrc" >> /home/$ST2110_USER/.bashrc
    fi

    install -m 755 $TOP_DIR/config/st2110.init /etc/init.d/st2110
    update-rc.d st2110 defaults
    update-rc.d st2110 enable
    install -m 755 $TOP_DIR/ptp/ptp.init /etc/init.d/ptp
    update-rc.d ptp defaults
    update-rc.d ptp enable
}

set -x
case "$1" in
    common)
        install_common_tools
        install_dev_tools
        install_config
        ;;
    ptp)
        install_ptp
        ;;
    transcoder)
        install_transcoder
        ;;
    capture)
        install_capture
        ;;
    ebulist)
        install_list
        ;;
    nmos)
        install_nmos
        ;;
    *)
        echo "Usage: $0 <common|ptp|transcoder|capture|ebulist|nmos>"
        ;;
esac
set +x
