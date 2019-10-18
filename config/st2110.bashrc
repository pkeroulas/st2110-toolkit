echo "-----------------------------------------------"
echo "          SMPTE ST 2110 TOOLKIT SERVER         "
echo "-----------------------------------------------"

printf  "%-30.30s: %s\n" "Master init script:" "/etc/init.d/st2110"
printf  "%-30.30s: %s\n" "Network config:" "/etc/netplan/*"
printf  "%-30.30s: %s\n" "Network reload cmd:" "$ sudo netplan apply"

st2110_conf=/etc/st2110.conf
if [ -f $st2110_conf ]; then
        source $st2110_conf
        export $(grep -v "^#" $st2110_conf | cut -d= -f1)
        printf  "%-30.30s: %s\n" "Master ST 2110 config file:" "$st2110_conf"
else
        printf  "%-30.30s: %s\n" "Master ST 2110 config file:" "$st2110_conf(missing)"
fi

printf  "%-30.30s: %s\n" "EBU-LIST control script:" "ebu_list_ctl"
echo
echo "-----------------------------------------------"
ebu_list_ctl show_usage
echo
ebu_list_ctl status
