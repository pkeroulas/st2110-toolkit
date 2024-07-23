#!/bin/bash
#
# Compile & Install everything for FFMPEG transcoding
# and tcpdump capturing and EBU-LIST

set -euo pipefail

usage(){
    echo "Usage: $0 <section>
sections are:
    * common:       compile tools, network utilities, config
    * ptp:          linuxptp
    * transcoder:   ffmpeg, x264, mp3 and other codecs
    * capture:      dpdk-based capture engine for Mellanox ConnectX-5
    * ebulist:      EBU-LIST pcap analyzer, NOT tested for a while
    * nmos:         Sony nmos-cpp node and scripts for SDP patching

Regardless of your setup, please install 'common' section first.
"
}

if [ ! $UID -eq 0  ]; then
    echo "Not root, exit."
    exit 1
fi
if [ $# -eq 0 ]; then
    echo "Missing args."
    usage
    exit 1
fi

TOP_DIR=$(dirname $(readlink -f $0))
ST2110_CONF_FILE=/etc/st2110.conf
OS=$(cat "/etc/os-release" | sed -n 's/^ID=\(.*\)/\1/p' | tr -d '"')
echo "OS: $OS detected"

if [ $OS = "debian" -o $OS = "ubuntu" ]; then
    PACKAGE_MANAGER=apt
elif [ $OS = "centos" -o $OS = "redhat" ]; then
    PACKAGE_MANAGER=yum
else
    echo "OS not supported."
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
        jq \
        libtool \
        make \
        net-tools \
        patch \
        perl \
        python-is-python3 \
        sshpass \
        tar \
        tcpdump \
        tmux \
        wget \
        wireshark-common

    if [ $PACKAGE_MANAGER = "yum" ]; then
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
    groupadd -f pcap
    for p in tcpdump ip iptables; do
        bin=$(readlink -f $(which $p))
        chgrp pcap $bin
        setcap cap_net_raw,cap_net_admin=eip $bin
    done
}

install_dev_tools()
{
    if [ $PACKAGE_MANAGER = "yum" ]; then
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
        install -m 644 $TOP_DIR/config/st2110.conf $ST2110_CONF_FILE
        echo "************************************************"
        echo "Default config installed: $ST2110_CONF_FILE"
        echo "If necessary, change ST2110_USER inside and create user on this system."
        echo "Then run again."
        echo "************************************************"
    fi
    source $ST2110_CONF_FILE

    if [ ! -d /home/$ST2110_USER ]; then
        echo "************************************************"
        echo "/home/$ST2110_USER doesn't exist. Verify ST2110_USER in $ST2110_CONF_FILE"
        echo "and add the appropriate user on this system if necessary."
        echo "Then run again."
        echo "************************************************"
        exit -1
    fi

    install -m 666 $TOP_DIR/config/st2110.bashrc /home/$ST2110_USER/
    if ! grep -q 2110 /home/$ST2110_USER/.bashrc; then
        echo "source /home/$ST2110_USER/st2110.bashrc" >> /home/$ST2110_USER/.bashrc
    fi

    install -m 755 $TOP_DIR/config/st2110.init /etc/init.d/st2110
    update-rc.d st2110 defaults
    systemctl enable st2110
}

#set -x

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
        usage
        ;;
esac
set +x
