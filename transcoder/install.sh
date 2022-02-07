# !!! Don't execute this script directly !!!
# It is imported in $TOP/install.sh

export FDKAAC_VERSION=0.1.4 \
    YASM_VERSION=1.3.0 \
    NASM_VERSION=2.13.02 \
    MP3_VERSION=3.99.5 \
    MAKEFLAGS="-j$[$(nproc) + 1]"

if [ -z $PACKAGE_MANAGER ]; then
    echo  "$PACKAGE_MANAGER undefined. Set to default 'apt'"
    PACKAGE_MANAGER=apt
fi
if [ -z $PREFIX ]; then
    echo  "$PREFIX undefined. Set to default '/usr/local'"
    PREFIX=/usr/local
fi
if [ -z $PKG_CONFIG_PATH ]; then
    echo  "$PKG_CONFIG_PATH undefined. Set to default."
    export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
fi

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
    $PACKAGE_MANAGER install nginx libnginx-mod-rtmp
    install -m 644 $THIS_DIR/config/nginx.conf /etc/nginx.conf
}

install_libsrt()
{
    if [ $OS = debian ]; then
        $PACKAGE_MANAGER install libsrt-dev libsrt1
    else
        $PACKAGE_MANAGER install srt-devel srt-libs
    fi
}

install_ffmpeg()
{
    cd $THIS_DIR
    dir=$(pwd)

    ldconfig -v
    echo "Installing ffmpeg"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone https://git.ffmpeg.org/ffmpeg.git
    cd ffmpeg
    git checkout master

    patch -p1 < $dir/transcoder/ffmpeg-force-input-threading.patch
    #patch -p1 < $dir/transcoder/ffmpeg-avformat-rtp-compute-smpte2110-timestamps.patch
    #patch -p1 < $dir/transcoder/ffmpeg-ffmpeg-avformat-rtp-compute-smpte2110-timestamps.patch

    ./configure --prefix=$PREFIX \
        --extra-cflags=-I$PREFIX/include \
        --extra-ldflags=-L$PREFIX/lib \
        --bindir=$PREFIX/bin \
        --extra-libs=-ldl \
        --enable-version3 --enable-gpl --enable-nonfree \
        --enable-postproc --enable-libsrt \
        --enable-libx264 --enable-libfdk-aac --enable-libmp3lame \
        --disable-ffplay --disable-ffprobe \
        $ffmpeg_gpu_options \
        --enable-small --disable-stripping --disable-debug

    make
    make install
    make distclean
    rm -rf $DIR
}

install_transcoder()
{
    install_yasm
    install_nasm
    install_x264
    install_fdkaac
    install_mp3
    install_libsrt
    install_ffmpeg
}
