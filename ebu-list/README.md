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
|NVMe SSD for OS|[Samsung PM981 Polaris 256GB M.2 NGFF PCIe Gen3 x4, NVME SSD, OEM (2280) MZVLB256HAHQ-00000](https://www.newegg.ca/samsung-pm981-256gb/p/0D9-0009-002R4)| 1 |
|NVMe for data cache|[Intel Optane M.2 2280 32GB PCIe NVMe 3.0 x2 Memory Module/System Accelerator MEMPEK1W032GAXT](https://www.newegg.ca/intel-optane-32gb/p/N82E16820167427)| 1 |
|Network controller|[Mellanox Connectx-5](https://www.mellanox.com/page/products_dyn?product_family=260&mtag=connectx_5_en_card)|1|
|Thermal compound|[Arctic Silver AS5-3.5G Thermal Compound](https://www.newegg.ca/arctic-silver-as5-3-5g/p/N82E16835100007)| 1 |
|Heat sink|[Noctua NH-L9i, Premium Low-profile CPU Cooler for Intel LGA115x](https://www.newegg.ca/p/N82E16835608029)| 1 |
|Computer case|[APEVIA X-FIT-200 Black Steel Mini-ITX Tower Computer Case 250W Power Supply](https://www.newegg.ca/p/N82E16811144255)| 1 |

### OS

Boot Ubuntu 18.04 from USB stick.

Install on Samsung M.2 drive.

### BIOS

TODO

### RAID 0 array for user data

From here, most of installation commands require root priviledges.

Find the 2 SATA drives and create RAID 0 array:

```sh
lsblk | grep sd
mdadm --create --verbose /dev/md0 --level=0 --raid-devices=2 /dev/sda /dev/sdb
cat /proc/mdstat
```

Create an EXT4 file system, create the mount point and mount:

```sh
mkfs.ext4 -F /dev/md0
mkdir -p /media/raid0
mount /dev/md0 /media/raid0
```

For persistent mounting, add this line in `/etc/fstab`:

```
/dev/md0 /media/raid    ext4    defaults 0      1
```

TODO: check permission

### Data cache

TODO: create bcache to improve SSD performance

### Mellanox network controller

ST-2110-ready NIC is mandatory to perform accurate analysis. Mellanox
Connectx-5 is selected to benefit from VMA library for hardware-accelerated
capture. Mellanox drivers has to be manually downloaded from
[here](https://docs.mellanox.com/display/MLNXOFEDv461000/Downloading+Mellanox+OFED).
Select the .iso image. Then start the installation:

```sh
cd <st2110-toolkit-directory>
source ./install.sh
cd <directory-where-the-iso-is-located>
install_mellanox
```

## Software installation steps

Install all the depencies:

```sh
source ./install.sh
install_config
install_common_tool
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

`ptp4linux` package and config was installed in 1st step.

#### Capture Engine

Regarding the capturing method, in EBU-LIST source tree, see
'apps/capture_probe/config.yml' to select one of the 2 solution:

* regular tcpdump which run with generic NIC (limited precision
  regarding packet timestamping)
* custom recorder which relies on VMA accelaration with Mellanox (need
  for EBU support for activation)

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
Mongo DB                      : UP
Influx DB                     : UP
Rabbit MQ                     : UP
LIST server                   : UP
LIST gui                      : UP
LIST capture                  : UP
```
