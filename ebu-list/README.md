# EBU-LIST server integration guide

This is the integration guide for [EBU LIST](https://tech.ebu.ch/list).
Although the project documentation allows to setup an offline analyzer,
this guide gives instructions to build a standalone, high performance
capturing devices.

* [Online running instance: EBU LIST](http://list.ebu.io/login) (no capture)
* [Sources](https://github.com/ebu/pi-list)

Sponsored by:

![logo](https://site-cbc.radio-canada.ca/site/annual-reports/2014-2015/_images/about/services/cbc-radio-canada.png)

## Suggested Hardware + OS

### Part list

| What | Item | Qty |
|------|------|-----|
|Motherboard|[Gigabyte Z390 AORUS PRO Wifi Intel Z390/socket1151 rev 1.0](https://www.gigabyte.com/ca/Motherboard/Z390-I-AORUS-PRO-WIFI-rev-10)| 1 (obsolete)|
|CPU|[Intel Core i5-9600K Coffee Lake 6-Core 3.7 GHz (4.6 GHz Turbo) LGA 1151 (300 Series) 95W BX80684I59600K Desktop Processor Intel UHD Graphics 630](https://www.newegg.ca/core-i5-9th-gen-intel-core-i5-9600k/p/N82E16819117959)| 1 |
|RAM|[G.SKILL Aegis 16GB (2 x 8GB) 288-Pin DDR4 SDRAM DDR4 3000 (PC4 24000) Intel Z170 Platform Memory (Desktop Memory) Model F4-3000C16D-16GISB ](https://www.newegg.ca/g-skill-16gb-288-pin-ddr4-sdram/p/N82E16820232417)| 1 |
|SSD for user data|[SAMSUNG 860 EVO Series 2.5" 500GB SATA III V-NAND 3-bit MLC Internal Solid State Drive (SSD) MZ-76E500B/AM](https://www.newegg.ca/samsung-860-evo-series-500gb/p/N82E16820147674) | 2 |
|SATA III cable|[Coboc Model SC-SATA3-18 18" SATA III 6Gb/s Data Cable](https://www.newegg.ca/p/N82E16812422752?Description=SATA%20III%20&cm_re=SATA_III-_-12-422-752-_-Product)| 2 |
|NVMe SSD for OS|[Samsung PM981 Polaris 256GB M.2 NGFF PCIe Gen3 x4, NVME SSD, OEM (2280) MZVLB256HAHQ-00000](https://www.newegg.ca/samsung-pm981-256gb/p/0D9-0009-002R4)| 1 |
|NVMe for data cache|[Intel Optane M.2 2280 32GB PCIe NVMe 3.0 x2 Memory Module/System Accelerator MEMPEK1W032GAXT](https://www.newegg.ca/intel-optane-32gb/p/N82E16820167427)| 1 |
|Network controller|[Mellanox Connectx-5](https://www.newegg.ca/p/14U-005H-00068)| 1 |
|Thermal compound|[Arctic Silver AS5-3.5G Thermal Compound](https://www.newegg.ca/arctic-silver-as5-3-5g/p/N82E16835100007)| 1 |
|Heat sink|[Noctua NH-L9i, Premium Low-profile CPU Cooler for Intel LGA115x](https://www.newegg.ca/p/N82E16835608029)| 1 |
|Computer case|[APEVIA X-FIT-200 Black Steel Mini-ITX Tower Computer Case 250W Power Supply](https://www.newegg.ca/p/N82E16811144255)| 1 |
|Replacement Power Supply|[Sylver Stone FX350-G](https://www.silverstonetek.com/product.php?pid=784&area=en)| 1 |

TODO: photos

### OS

#### Boot Ubuntu 18.04 from USB stick.

* [Create a bootable USB stick with Ubuntu 18.04 inside](https://tutorials.ubuntu.com/tutorial/tutorial-create-a-usb-stick-on-ubuntu#0)
* plug the USB on the station and power up
* press F2 to enter the BIOS setup.
* select UEFI USB stick as a primary boot device
* set correct time
* set `AC back` = `Always on` (auto startup on power failure)
* `Fan failure warning` = `on`
* save and exit BIOS

#### OS install

* start Ubuntu installer
* select "Minimal installation"
* no disk encryption nor LVM required
* select target disk for OS, i.e. the largest NVMe
* user: ebulist
* computer's name: ebulist-light-<dpt>-<id> (example: ebulist-light-maint-0)
* restart

#### OS init setup

From here, use the terminal. Install basic tools:

```sh
sudo -i
apt udpate
apt udgrade
apt install openssh-server git
```

OS update may break Mellanox drivers, see `install_mellanox` function
for detail. Disable automatic update in `/etc/apt/apt.conf.d/20auto-upgrades` (need for root priviledges).

```sh
APT::Periodic::Update-Package-Lists "0";
```

### RAID 0 array for user data

Raid 0 consists in splitting data into segment and writting portions on
multiple disks simultaneous to maximize the throughput.
See [additional performance tests](#throughput) for alternatives.

Find the 2 SATA drives and create RAID 0 array. From here, most of
installation commands require root priviledges.

```sh
sudo -i
apt install mdadm
lsblk | grep sd
mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/sda /dev/sdb
ls /dev/md*
cat /proc/mdstat
```

Create an EXT4 file system, create the mount point, mount and set
ownership:

```sh
mkfs.ext4 -F /dev/md0
mkdir -p /media/raid0
mount /dev/md0 /media/raid0
chown -R ebulist:ebulist /media/raid0/*
```

For persistent naming:

```sh
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
update-initramfs -u # sync ramdisk version of conf file
```

And persitent mounting, add this in `/etc/fstab`:

```
/dev/md0 /media/raid0   ext4    defaults 0      1
```

### Install ST 2110 depencies

As `ebulist` user:

```sh
cd ~
git clone https://github.com/pkeroulas/st2110-toolkit.git
```

As `root` user:

```sh
sudo -i
cd /home/ebulist/st2110-toolkit
./install.sh common
vi /etc/st2110.conf
source ./install.sh
```
### Mellanox network controller

ST-2110-ready NIC is mandatory to perform accurate analysis. Connectx-5 is selected to benefit from VMA library for hardware-accelerated capture. Verify the NIC is detected:

```sh
lspci -v | grep Mellanox
...
```

Mellanox drivers has to be manually downloaded [here.](https://www.mellanox.com/page/products_dyn?product_family=26&mtag=linux_sw_drivers)

* Select: "Download > LatestVersion > Ubuntu > Ubuntu 18.04 > x86_64 > ISO"
* Accept End User License Agreement
* Copy in the home directory
* Start the installation which takes a while:

```sh
install_mellanox ../MLNX_OFED_LINUX-4.7-1.0.0.1-ubuntu18.04-x86_64.iso
```

If dkms fails to build, see comment `install_mellanox` function in
`intall.sh` script.

Note the serial number, needed later:

```sh
sudo mlxfwmanager | grep GUID
```

If something goes wrong, you may find additional [installation documentation.](https://docs.mellanox.com/display/MLNXOFEDv461000/Downloading+Mellanox+OFED).

## EBU-LIST install

Install all the dependencies, still as `root`:

```sh
install_list
```

At this point, all the services should be enabled but not configured.

### Configuration

#### Master config

Edit master config (/etc/st2110.conf), especially the 'Mandatory' part
which contains physical port names, path, etc. This config is loaded by
every script of this toolkit, including EBU-LIST startup script and it
is loaded on ssh login as well.

#### PTP

Verify that `linuxptp` package is already installed.

```sh
dpkg --list | grep linuxptp
```

Config file is `/etc/ptp/ptp4l.conf`.

#### Capture Engine

Regarding the capturing method, in EBU-LIST source tree, see
'list/apps/capture_probe/config.yml' to select one of the 2 solution:

* regular `tcpdump` run with generic NIC (limited precision
  regarding packet timestamping, not suitable for UHD video)
* alternative capture method for better time precision

dpdk-based captured:

```sh
apt install node npm
git clone https://github.com/ebu/pi-list.git
cd app/capture_probe/
npm install
cd js_common_server
npm install
cd list/
sudo node server.js config.yml
```

### Controls

Master init script needs root priviledge to start the NIC and PTP and start
a user session to run EBU-LIST

```sh
$ sudo /etc/init.d/st2110
Usage: /etc/init.d/st2110 {start|stop|log}
        log <list|ptp|system>
```

EBU-LIST is controlled by a dedicated script:

```sh
$ ebu_list_ctl
/usr/sbin/ebu_list_ctl is a wrapper script that manages EBU-LIST
and related sub-services (DB, backend, UI, etc.)
Usage:
    /usr/sbin/ebu_list_ctl {start|stop|status|log|install|upgrade|dev}
        start    start docker containers and server
        stop     stop docker containers and server
        status   check the status of all the st 2110 services
        log      get the logs of the server+containers
        install  install EBU-LIST for the first time
        upgrade  upgrade to next stable version fron public Github
        dev      upgrade to the next release from private repo

$ ebu_list_ctl status
-----------------------------------------------
                EBU-LIST Status
-----------------------------------------------
Media interfaces
Name                 ebulist-light-maint-2
Managment iface      UP    eno2                      192.168.2.108
-----------------------------------------------
Media interfaces
NIC driver           UP
Interface 0          UP    enp1s0f0                  192.168.105.93
Gateway   0          UP    ifname                    Ethernet24
Switch    0          UP    XXXXXXXXXXXXXXXXXXXXXXXX. 192.168.253.8
Interface 1          UP    enp1s0f1                  192.168.107.241
Gateway   1          UP    ifname                    Ethernet54/1
Switch    1          UP    XXXXXXXXXXXXXXXXXXXXXXXX. 192.168.253.8
-----------------------------------------------
PTP
ptp4l                UP
phc2sys   0          UP
phc2sys   1          UP
Lock                 UP
Ptp traffic          UP
-----------------------------------------------
Docker
Daemon               UP
Network              UP
Service Mongo DB     UP
Service Influx DB    UP
Service Rabbit MQ    UP
-----------------------------------------------
LIST
Profile              prod
container            UP
API response         UP
GUI response         UP
probe 0              DOWN
probe 1              DOWN
```

#### Upgrade

```sh
sudo service docker stop
ebu_list_ctl upgrade
sudo service docker start
ebu_list_ctl status
```

### Throughput

Use M.2 nvme SDD as a buffer for pcap file capture.

```sh
lsblk | grep nvme  # find the one that IS NOT used for OS
fdisk /dev/nvme0n1 # create new partition 'n', primary 'p', default size, save 'w'
mkfs.ext4 -F /dev/nvme0n1p1
mkdir -p /media/buffer
mount /dev/nvme0n1p1 /media/buffer
chown -R ebulist:ebulist /media/buffer/*
```
TODO tune block sizes

For persistent mounting, add this line in `/etc/fstab`:

```
UUID=nvme_UUID /media/buffer ext4 defaults 0 0
```

Determine write throughput for a given drive:

```
dd if=/dev/zero of=/media/buffer/zero.img bs=1G count=1 oflag=dsync
```

| Drive | FS | W speed MB/s |
|-------|----|--------------|
| RAM   |    | 2,400 |
| nvme0 | ext4 | 262 |
| nvme1 | ext4 | 683 |
| SSD   | ext4, raid0 | 651 |

To be tested:

* nvme0 used as [bcache device](https://www.linux.com/tutorials/using-bcache-soup-your-sata-drives/)
* Fusion IO card (spec: 900 MB/s)

