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

install_monitoring_tools()
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
}

install_yasm()
{
    echo "Installing YASM"
    DIR=$(mktemp -d)
    cd $DIR/
    curl -s http://www.tortall.net/projects/yasm/releases/yasm-$YASM_VERSION.tar.gz |
        tar zxvf - -C .
    cd $DIR/yasm-$YASM_VERSION/
    ./configure --prefix="$PREFIX" --bindir="$PREFIX/bin" --docdir=$DIR -mandir=$DIR
    make
    make install
    make distclean
    rm -rf $DIR
}

install_nasm()
{
    echo "Installing NASM"
    if [ $OS = "redhat" ]; then
        DIR=$(mktemp -d)
        cd $DIR/
        nasm_rpm=nasm-$NASM_VERSION-0.fc24.x86_64.rpm
        curl -O https://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/linux/$nasm_rpm
        rpm -i $nasm_rpm
        rm -f $nasm_rpm
        rm -rf $DIR
    else
        $PACKAGE_MANAGER -y install nasm
    fi
}

install_x264()
{
    echo "Installing x264"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone -b stable  --single-branch http://git.videolan.org/git/x264.git
    cd x264/
    ./configure --prefix="$PREFIX" --bindir="$PREFIX/bin" --enable-shared
    make
    make install
    make distclean
    rm -rf $DIR
}

install_fdkaac()
{
    echo "Installing fdk-aac"
    DIR=$(mktemp -d)
    cd $DIR/
    curl -s https://codeload.github.com/mstorsjo/fdk-aac/tar.gz/v$FDKAAC_VERSION |
        tar zxvf - -C .
    cd fdk-aac-$FDKAAC_VERSION/
    autoreconf -fiv
    ./configure --prefix="$PREFIX" --disable-shared
    make CXXFLAGS="-std=gnu++98" # compatibility with gcc v7...
    make install
    make distclean
    rm -rf $DIR
}

install_mp3()
{
    echo "Installing mp3"
    DIR=$(mktemp -d)
    cd $DIR/
    curl -s -L http://downloads.sourceforge.net/project/lame/lame/3.99/lame-$MP3_VERSION.tar.gz |
        tar zxvf - -C .
    cd lame-$MP3_VERSION/
    ./configure --prefix="$PREFIX" --bindir="$PREFIX/bin" --disable-shared --enable-nasm
    make
    make install
    make distclean
    rm -rf $DIR
}

install_ffnvcodec()
{
    echo "Installing ffnvcodev"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git
    cd nv-codec-headers
    make
    make install
    make distclean
    rm -rf $DIR
    # provide new option to ffmpeg
    ffmpeg_gpu_options="--enable-cuda --enable-cuvid --enable-nvenc --enable-libnpp --extra-cflags=-I$PREFIX/cuda/include --extra-ldflags=-L$PREFIX/cuda/lib64"
}

install_streaming_server()
{
    apt install nginx libnginx-mod-rtmp
    install -m 644 $THIS_DIR/config/nginx.conf /etc/nginx.conf
}

install_ffmpeg()
{
    ldconfig -v
    echo "Installing ffmpeg"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://github.com/cbcrc/FFmpeg.git
    cd FFmpeg
    git checkout SMPTE2110/master

    ./configure --prefix=$PREFIX \
        --extra-cflags=-I$PREFIX/include \
        --extra-ldflags=-L$PREFIX/lib \
        --bindir=$PREFIX/bin \
        --extra-libs=-ldl \
        --enable-version3 --enable-gpl --enable-nonfree \
        --enable-postproc --enable-avresample \
        --enable-libx264 --enable-libfdk-aac --enable-libmp3lame \
        --disable-ffplay --disable-ffprobe \
        $ffmpeg_gpu_options \
        --enable-small --disable-stripping --disable-debug

    make
    make install
    make distclean
    rm -rf $DIR
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

install_config()
{
    set -x
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

    install -m 644 $THIS_DIR/ptp/ptp4l.conf     /etc/linuxptp/ptp4l.conf
    install -m 755 $THIS_DIR/config/st2110.init /etc/init.d/st2110
    update-rc.d st2110 defaults
    update-rc.d st2110 enable

    install -m 755 $THIS_DIR/ebu-list/ebu_list_ctl /usr/sbin/
    install -m 755 $THIS_DIR/ebu-list/captured /usr/sbin/
    set +x
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

install_list()
{
    $PACKAGE_MANAGER install -y \
        docker \
        docker-compose

    if [ -f  $ST2110_CONF_FILE ]; then
        source $ST2110_CONF_FILE
    else
        echo "Config should be installed first (install_config) and EDITED, exit."
        exit 1
    fi

    usermod -a -G adm $ST2110_USER # journalctl
    usermod -a -G pcap $ST2110_USER
    usermod -a -G docker $ST2110_USER

    LIST_DIR=/home/$ST2110_USER/pi-list
    install -m 755 $THIS_DIR/ebu-list/ebu_list_ctl /usr/sbin/
    install -m 755 $THIS_DIR/ebu-list/captured /usr/sbin/
    su $ST2110_USER -c "ebu_list_ctl install"
}

source $THIS_DIR/nmos/install.sh

install_all()
{
    install_config
    install_common_tools
    install_monitoring_tools
    install_ptp
    install_yasm
    install_nasm
    install_x264
    install_fdkaac
    install_mp3
    install_ffmpeg
    install_smcroute
    install_nmos
    install_list
}
