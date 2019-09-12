echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "%       ST2110 SERVER        %"
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

echo "Network config: /etc/netplan/*"
echo "      $ sudo netplan apply"
echo

st2110_conf=/etc/st2110.conf
echo "Master ST 2110 config file: $st2110_conf"
echo
if [ -f $st2110_conf ]; then
        source $st2110_conf
        export $(grep -v "^#" $st2110_conf | cut -d= -f1)
else
        echo "Missing $st2110_conf"
fi

echo "Master init script: /etc/init.d/st2110"
echo

echo "EBU-LIST utility: ebu_list_ctl"
echo

ebu_list_ctl show_usage

ebu_list_ctl status
