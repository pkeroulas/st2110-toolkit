# !!! Don't execute this script directly !!!
# It is imported in $TOP/install.sh

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

    ln -fs $TOP_DIR/ebu-list/ebu_list_ctl /usr/sbin/ebu_list_ctl

    # su $ST2110_USER -c "ebu_list_ctl install"
    cd /home/$ST2110_USER
    git clone https://github.com/ebu/pi-list.git $LIST_PATH
    cd $LIST_PATH
    git submodule update --init --recursive
    ./scripts/setup_build_env.sh

    # dev mode means build application from source
    if [ $LIST_DEV = "true" ]; then
        ./scripts/deploy/deploy.sh
    else
        # whereas non dev mode means install from public docker image
        cd $LIST_PATH/docs
        docker-compose pull

        # but still need to build node apps to run the capture probe
        cd $LIST_PATH/
        ./scripts/build_node.sh
    fi

    chown -R $ST2110_USER:$ST2110_USER $LIST_PATH

    cp $TOP_DIR/ebu-list/ebulist.service /lib/systemd/system
    install -m 755 $TOP_DIR/ebu-list/ebulist-probe.init /etc/init.d/ebulist-probe
    cp $TOP_DIR/ebu-list/ebulist-probe.service /lib/systemd/system

    systemctl daemon-reload
    systemctl enable ebulist
    systemctl enable ebulist-probe
}
