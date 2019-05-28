# EBU-LIST server integration guide

This is the integration guide for [EBU LIST](http://list.ebu.io/login).
Although the project documentation allows to setup an offline analyzer, additional instructions are required for a complete capturing device. This include:

* master init script + config
* linuxptp + config
* NIC settings
* LIST server startup script + config generated from master config

## Installation steps

From top directory:

```
source install.sh
install_config
install_common
install_list
```

## Capture engine:

2 choices:
* regular tcpdump which run with generic NIC (limited precision)
* custom recoder which relies on VMA accelaration with Mellanox

The capture engine is hard-coded is EBU-LST source:
apps/listwebserver/controllers/capture.js, line 47-48

## Configuration

Edit master config (/etc/st2110.conf), especially the 'Mandatory' part
which contains physical port names and data folder.

## Startup

Installed initscript starts up all runtime dependencies:

* Mellanox controller
* linuxptp
* LIST server

Start all at once:
```
sudo /etc/init.d/st2110 start
```

You can monitor the server, the ptp logs or system/process logs:

```
sudo /etc/init.d/st2110 log list
sudo /etc/init.d/st2110 log ptp
sudo /etc/init.d/st2110 log system
```

#TODO nodemon is not installed
