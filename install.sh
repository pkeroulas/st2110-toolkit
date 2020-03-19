#!/bin/bash
#
# Compile & Install everything for FFMPEG transcoding
# and tcpdump capturing and EBU-LIST

#set -euo pipefail

THIS_DIR=.
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
    FDKAAC_VERSION=0.1.4 \
    YASM_VERSION=1.3.0 \
    NASM_VERSION=2.13.02 \
    MP3_VERSION=3.99.5 \
    PTP_VERSION=2.0 \
    SMCROUTE_VERSION=2.4.3 \
    PREFIX=/usr/local \
    MAKEFLAGS="-j$[$(nproc) + 1]"

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig \

echo "${PREFIX}/lib" >/etc/ld.so.conf.d/libc.conf

source $THIS_DIR/capture/install.sh
source $THIS_DIR/ebulist/install.sh
source $THIS_DIR/nmos/install.sh
source $THIS_DIR/transcoder/install.sh

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
        g++ \
        git \
        libtool \
        libssl-dev \
        make \
        net-tools \
        patch \
        perl \
        tar \
        tcpdump \
        tmux \
        wget \
        zlib1g-dev

    if [ $OS = "redhat" ]; then
        $PACKAGE_MANAGER -y update && $PACKAGE_MANAGER install -y \
            nc \
            gcc-c++ \
            openssl-devel \
            which \
            zlib-devel
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
        install -m 644 $THIS_DIR/config/st2110.conf $ST2110_CONF_FILE
    else
        source $ST2110_CONF_FILE
    fi

    install -m 666 $THIS_DIR/config/st2110.bashrc /home/$ST2110_USER/
    if ! grep -q 2110 /home/$ST2110_USER/.bashrc; then
        echo "source /home/$ST2110_USER/st2110.bashrc" >> /home/$ST2110_USER/.bashrc
    fi

    install -m 755 $THIS_DIR/config/st2110.init /etc/init.d/st2110
    update-rc.d st2110 defaults
    update-rc.d st2110 enable
}

set -x
case "$1" in
    transcoder)
        install_config
        install_capture
        install_transcoder
        ;;
    capture)
        install_config
        install_capture
        ;;
    ebulist)
        install_config
        install_capture
        install_list
        ;;
    nmos)
        install_nmos
        ;;
    *)
        echo "Usage: $0 <transcoder|capture|ebulist|nmos>"
        ;;
esac
set +x
