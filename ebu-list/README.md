# EBU-LIST server integration guide

This is the integration guide for [EBU LIST](https://tech.ebu.ch/list).
Although the project documentation allows to setup an offline analyzer,
this guide gives instructions to build a standalone, high perforamce
capturing devices.

## Suggested Hardware + OS

### Part list

|*What*|*Item*|*Qty*|
|------|------|-----|
|Motherboard|[ASRock Z390 PHANTOM GAMING-ITX/AC LGA 1151 (300 Series) Intel Z390 HDMI SATA 6Gb/s USB 3.1 Mini ITX Intel Motherboard](https://www.newegg.ca/p/N82E16813157854)| 1 |
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

TODO: photos

### OS

#### Boot Ubuntu 18.04 from USB stick.

* [Create a bootable USB stick with Ubuntu 18.04 inside](https://tutorials.ubuntu.com/tutorial/tutorial-create-a-usb-stick-on-ubuntu#0)
* plug the USB on the station and power up
* press F2 to enter the BIOS setup.
* select UEFI USB stick as a primary boot device
* set correct time
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

From here, most of installation commands require root priviledges.

```sh
sudo -i
```

Find the 2 SATA drives and create RAID 0 array:

```sh
apt install mdadm
ls /dev/md*
lsblk | grep sd
mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/sda /dev/sdb
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

For persistent mounting, add this line in `/etc/fstab`:

```
/dev/md0 /media/raid0   ext4    defaults 0      1
```

### Data cache

TODO:
[Create bcache to improve SSD performance.](https://www.linux.com/tutorials/using-bcache-soup-your-sata-drives/)

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
source ./install.sh
install_common_tool
install_monitoring_tools
install_config
source /etc/st2110.conf
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
lspci -xxxvvv | grep "\[SN\] Serial number:"
```

If something is worng, you may find additional [installation documentation.](https://docs.mellanox.com/display/MLNXOFEDv461000/Downloading+Mellanox+OFED).

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
'apps/capture_probe/config.yml' to select one of the 2 solution:

* regular `tcpdump` run with generic NIC (limited precision
  regarding packet timestamping, not suitable for UHD video)
* custom `recorder` (not installed by default) relies on Mellanox VMA
  accelaration. EBU support is needed for activation, provide NIC serial number)

### Control

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
Usage: /usr/sbin/ebu_list_ctl {start|stop|status|log|upgrade}
$ ebu_list_ctl
Status:
Media interface               : UP
Ptp for Linux daemon          : UP
Ptp to NIC                    : UP
Docker daemon                 : UP
Docker network                : UP
Mongo DB                      : UP
Influx DB                     : UP
Rabbit MQ                     : UP
LIST server                   : UP
LIST gui                      : UP
LIST capture                  : UP
```

#### Upgrade

```sh
sudo service docker stop
ebu_list_ctl upgrade
vi pi-list/apps/capture_probe/config.yml #select tcpdump or custom recorder
sudo service docker start
ebu_list_ctl status
```
