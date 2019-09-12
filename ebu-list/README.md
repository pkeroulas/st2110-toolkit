# EBU-LIST server integration guide

This is the integration guide for [EBU LIST](https://tech.ebu.ch/list).
Although the project documentation allows to setup an offline analyzer,
additional instructions are required for a complete capturing device.

This include:

* master control script + config
* linuxptp + config
* NIC settings

## Installation steps

From top directory:

```
source install.sh
install_config
install_common
install_list
```

At this point, all the services should be enabled.

## Capture engine:

2 choices:

* regular tcpdump which run with generic NIC (limited precision
  regarding packet timestamping)
* custom recoder which relies on VMA accelaration with Mellanox (need
  for EBU support for activation)

## Configuration

Edit master config (/etc/st2110.conf), especially the 'Mandatory' part
which contains physical port names, path, etc. This config is loaded by
every script of this toolkit, including EBU-LIST startup script and it
is loaded on ssh login as well.

## Control

```
$ ebu_list_ctl
Usage: /usr/sbin/ebu_list_ctl {start|stop|status|log|upgrade}
$ ebu_list_ctl
Status:
Media interface               : UP
Ptp for Linux daemon          : UP
Ptp to NIC                    : UP
Docker daemon                 : UP
Mongo DB                      : UP
Influx DB                     : UP
Rabbit MQ                     : UP
LIST server                   : UP
LIST gui                      : UP
LIST capture                  : UP
```
