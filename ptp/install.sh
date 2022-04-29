export PTP_VERSION=3.1

install_ptp()
{
    # build+patch linuxptp instead of installing pre-built package
    cd $TOP_DIR
    dir=$(pwd)
    echo "Installing PTP"
    DIR=$(mktemp -d)
    cd $DIR/
    git clone http://git.code.sf.net/p/linuxptp/code linuxptp
    cd linuxptp
    git checkout -b $PTP_VERSION v$PTP_VERSION
    # https://sourceforge.net/p/linuxptp/mailman/linuxptp-devel/thread/014101d3ddea%24c3a76690%244af633b0%24%40de/#msg36304311
    patch -p1 < $dir/ptp/0001-port-do-not-answer-in-case-of-unknown-mgt-message-co.patch
    make
    make install
    make distclean
    rm -rf $DIR

    mkdir /etc/linuxptp
    install -m 644 $TOP_DIR/ptp/ptp4l.conf     /etc/linuxptp/ptp4l.conf

    install -m 755 $TOP_DIR/ptp/ptp.init /etc/init.d/ptp
    update-rc.d ptp defaults
    systemctl enable ptp
}
