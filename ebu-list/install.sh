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

    LIST_DIR=/home/$ST2110_USER/pi-list
    install -m 755 $TOP_DIR/ebu-list/ebu_list_ctl /usr/sbin/
    #TODO docker not active yet
    su $ST2110_USER -c "ebu_list_ctl install"
}

