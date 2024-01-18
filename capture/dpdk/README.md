# Capture ST 2110 video streams using DPDK

The proposed solution supports:

- Hardware timestamping in nanoseconds
- Dual-port
- Join and capture multiple streams
- IP/port filtering
- Throughput up to 13Gbps

```mermaid
  graph TD;
      A-->B;
      A-->C;
      B-->D;
      C-->D;
```

And it is tested on a [mini PC running Ubuntu >=20.04, equipped with a Mellanox ConnectX-5 card @ 100Gbps](https://github.com/pkeroulas/st2110-toolkit/tree/master/ebu-list) and a FPGA-based source.

- [Getting started](#Getting-started)
    - [DPDK](#DPDK)
    - [Build](#Build)
    - [Mellanox NIC setup](#Mellanox-NIC-setup)
    - [Execution](#Execution)
- [Features](#Features)
    - [Hardware timestamps](#Hardware-timestamps)
    - [Filter](#Filter)
- [Search for DPDK-based capture apps](#Search-for-DPDK-based-capture-apps)
    - [Sample application](#Sample-application)
    - [Tcpdump](#Tcpdump)
- [Proposed solution](#Proposed-solution)
    - [Wrapper script](#Wrapper-script)
    - [Timestamps precision](#Timestamps-precision)
    - [Performances](#Performances)
    - [Duration](#Duration)
    - [Dual port capture for ST 2022-7](#Dual-port-capture-for-ST-2022-7)
    - [TODO](#TODO)

## Getting started

### DPDK

[DPDK](https://doc.dpdk.org/guides/index.html) is a set of high-efficient libraries that bypasses the kernel network stack and lets the packets be processed directly in the userspace. This allows to maximize the through for [traffic capture](https://doc.dpdk.org/guides/howto/packet_capture_framework.html). It supports a large set of NICs as opposed to Mellanox [libvma](https://github.com/Mellanox/libvma).

The architecture relies on a Poll Mode Driver instead of hardware interrupts, it is more CPU-intensive but it is faster.
It's all in userspace so easier for tweaking. It comes with application examples like `testpmd` and `dpdk-pdump` for traffic capture.

![arch](./dpdk-capture-diagram.jpg)

### Build

Dependency packages:

| *Package* | *Debian Version* |
|---|---|
| `rdma-core` | 18 |
| `libiverbs` | 18 |
| `libnuma-dev` | 2.0 |
| `libelf-dev` | 0.176 |
| `libpcap-dev` | 1.9 |

Those expose the appropriate symbols in `/usr/include/infiniband/` for `dpdk`.

Out of the box, *DPDK hardly makes the jobs for as a proper ST 2110 capture engine because of the inaccuracy of the incoming packets*.
[Timestamp](#hardware-timestamps) section brings more details. To overcome that limitation, You need to clone [my fork](https://github.com/pkeroulas/dpdk/tree/pdump_mlx5_hw_ts/clock_info/v1) based on version version v20.05.

```sh
git clone https://github.com/pkeroulas/dpdk.git
cd dpdk
git checkout -b hw_ts origin/pdump_mlx5_hw_ts/clock_info/v1
make defconfig
```

Apply following config in `./build/.config`:

```sh
CONFIG_RTE_LIBRTE_MLX5_PMD=y # Mellanox ConnectX-5 ethernet driver
CONFIG_RTE_LIBRTE_PMD_PCAP=y # write pcap files
CONFIG_RTE_LIBRTE_BPF_ELF=y  # Berkley Packet Filter support
```

```sh
make
sudo make install
```

### Mellanox NIC setup

```sh
iface=<name-of-your-interface>
ethtool --set-priv-flags $iface sniffer on
ethtool -G $iface rx 8192
hwstamp_ctl -i $iface -r 1
dpdk-devbind --status | grep "ConnectX"
```

### Execution

Primary process, read from eth driver and manage `pdump` server:

```sh
./build/app/testpmd -w 0000:01:00.0 -w 0000:01:00.1 -n4 --
```

Secondary process manages the `pdump` client and write to pcap file.

```sh
./build/app/dpdk-pdump -- --pdump 'port=0,queue=*,rx-dev=/tmp/test.pcap'
```

## Features

### Hardware timestamps

Raw timestamps are the captured values of the free running counter (one for each ethernet port).
Unfortunataly, out of the box DPDK doesn't convert those values coming from mlx5 to nanoseconds.
If not patch, the resulting pcap file does't satisfy the accuracy required by EBU-LIST analyzer.

2 methods for conversion:

| **Method**    | Device Frequency                                | HW Clock Info                                         |
|---------------|-------------------------------------------------|-------------------------------------------------------|
| **Idea**      | a device constant attribute that can be queried on startup | Use the converter implemented by Mellanox libiverbs `infiniband/mlxdv5.h` |
| **Branch**    | https://github.com/pkeroulas/dpdk/tree/pdump_mlx5_hw_ts/v6 | https://github.com/pkeroulas/dpdk/tree/pdump_mlx5_hw_ts/clock_info/v1     |
| **Pros**      | it is easy to implement, more acceptable for upstream contribution | **it just works**, with same precision as libvma |
| **Cons**      | **accuracy as bad as SW timestamping** | clock info needs to be updated thanks to a timer + this **[doesn't make a consensus in dpdk community](https://www.mail-archive.com/dev@dpdk.org/msg171599.html)**. See TODO section to go ahead  |

### Filter

Builtin filters **doesn't** work for mlx5:

```sh
> 5tuple_filter 1 add dst_ip 225.192.10.1 src_ip 192.168.105.1 dst_port 20000 src_port 10000 protocol 17 mask 0x1F tcp_flags 0 priority 2 queue 2
ntuple filter is not supported on port 1
> flow_director_filter 0 mode IP add flow ipv4-udp src 192.168.105.1 10000 dst 225.192.10.1 20000 tos 0 ttl 255 vlan 1 flexbytes (0x88,0x48) fwd pf queue 1 fd_id 1
net_mlx5: mlx5_flow.c:5644: flow_fdir_ctrl_func(): port 0 flow director mode 0 not supported
```

The workaround is to supply `testpmd` a compiled eBPF.
`clang` and `libc6-dev-i386` are required to compile example `./bpf.c`.

```
clang -O2 -I /usr/include/x86_64-linux-gnu/ -U __GNUC__ -target bpf -c ./bpf.c
testpmd> bpf-load rx 0 0 J ./bpf.o
```

Note that bpf filter applies to forward flows but the whole traffic from a port is still redirected to dpdk.

## Search for DPDK-based capture apps

| Solutions   | Filter | Dual port | Pros   | Cons  | Source |
|-------------|--------|-----------|--------|-------|--------|
| builtin app | y | y | good for testing  | not the best for integration | https://doc.dpdk.org/guides/tools/pdump.html |
| tcpdump     | y | y | lots of features  | bad performances  |  https://github.com/the-tcpdump-group/libpcap |
| dpdk-dump   | n | y | simple | old doesn't build anymore | https://github.com/marty90/DPDK-Dump |
| PcapPlusPlus| y | y | ?      | complicated        | https://github.com/seladb/PcapPlusPlus/tree/master/Examples/DpdkExample-FilterTraffic |
| dpdkcap     | n | y | snaplen, realtime stats | ? | https://github.com/dpdkcap/dpdkcap.git |
| dpdk-pcapng | ? | ? | ? | ? | https://github.com/shemminger/dpdk-pcapng.git |

### Sample application

Ususally, dpdk-based apps need the following variables:

```
cd ~/src/dpdk/examples/rxtx_callbacks
export RTE_SDK=/home/ebulist/src/dpdk
export RTE_TARGET=build
make
sudo ./examples/rxtx_callbacks/build/rxtx_callbacks -l 1 -n 4 -- -t
```

### Tcpdump

Working with tcpdump would be ideal because the versatily and the maturity.

* Build

    - dpdk v20.05 config: `CONFIG_RTE_BUILD_SHARED_LIB=y`
    - libpcap 1.8.1 source to be located in same folder as `./tcpdump/`.  `./configure --with-dpdk=<ABSOLUTE_path_to_dpdk> `
    - libpcap must be patched attached file to support HW tiemstamping
    - tcpdump:  `make`(`gcc  -DHAVE_CONFIG_H   -I. -I../libpcap  -g -O2  -o tcpdump fptype.o tcpdump.o  libnetdissect.a -lcrypto ../libpcap/libpcap.a -libverbs  -L/tmp/staging/usr/local/lib -ldpdk -lrt -lm -lnuma -ldl -pthread`)

* Exec

```sh
sudo DPDK_CFG="--log-level=debug -dlibrte_mempool_ring.so -dlibrte_common_mlx5.so -dlibrte_pmd_mlx5.so ./tcpdump -i dpdk:0 --time-stamp-precision=nano -j adapter_unsynced dst port 20000
```

* Results

**15% pkts dropped by interface**. This is due to libcap that makes [too many copies and syscalls and that should be improved later](https://inbox.dpdk.org/users/20200723165755.46cef46c@hermes.lan/).

## Proposed solution

### Wrapper script

DPDK builtin utilities (`testpmd` + `dpdk-pdump`) are chosen for their versatily considering that the tunning might be a long process.
[dpdk-capture.sh](./dpdk-capture.sh) wraps them in a tcpdump-like command line interpreter.
The overhead induced by multiple process being started/stopped is not an issue in our use case.

Additional dependencies:

- `smcroute`
- `screen`
- `linuxptp`

```sh
./dpdk-capture.sh -i enp1s0f0 -w /tmp/HD.pcap -G 1 dst 225.192.10.1
```

### Timestamps precision

Before starting the test, make sure that both NIC clock and system clock are synchronized with PTP master, using `linuxptp` for instance.

Note that a running DPDK application prevents the PTP daemon from receiving the PTP traffic. Both `ptp4l` and `phc2sys` somehow have a bad impact on NIC hardware clock, which makes the packet timestamping drift (few 10usec/s) until the capture app terminates and PTP traffic is received again. This occurs no matter if `linuxptp` elects the NIC clock as the best master clock during the interruption or not. However, turning PTP daemon off during the capture causes no time drift. There must be a way to prevent `linuxptp` from catching the whole traffic but `dpdk-capture.sh` just shuts down PTP service temporarly; this is acceptable since the capture duration is generally a few seconds. In case `testpmd` stays up forever, you need a fallback plan for some services:
* DHCP leases can't be renewed: use static a addresse instead
* PTP: capture on a single port A only (`testpmd` is given one `-w` pci interface) and dedicate port B to PTP sync. Then `phc2sys` have sync to port A with port B

Given a very stable (FPGA-based) stream source, the capture script produces a pcap file that can be validated using the following tools:

* [capinfos](https://www.wireshark.org/docs/man-pages/capinfos.html): duration, bitrate, format
* [Packet drop detector](https://github.com/pkeroulas/st2110-toolkit/blob/master/misc/pkt_drop_detector.py)
* [Vrx validation](https://github.com/ebu/smpte2110-analyzer/blob/master/vrx_analysis.py): jitter
* [EBU-list checks everything](https://tech.ebu.ch/list) including time drift (RTP Latency should be stable)

### Performances

| Bitrate in Gbps | pkt drops | Vrx | Comments |
|-----------------|-----------|-----|----------|
| 1.3 | 0 | ok | 1080i @ 60fps     |
| 5.2 | 0 | ok | 2160p @ 30fps           |
| 6.5 | 0 | ok | max on SSD              |
| 10.5  | 0 | ok | 2 sec, 2060p @ 60fps, need to write into RAM |
| 13  | 0 | ok | 1 sec, 2060p @ 60fps, need to write into RAM |
| 21  | ks | fail | 2x 2060p @ 60fps, pcap bitrate is 13Gpbs |

### Duration

Could write a 1080i@30fps stream (1.3Gbps) for 60 sec (10GB) on RAID 0 without any drop.

### Dual port capture for ST 2022-7

```sh
./dpdk-capture.sh -i enp1s0f0 -i enp1s0f1 -w /tmp/2_HD.pcap -G 1 dst 225.192.10.1 or dst 225.192.10.2
```

### TODO

* upstream changes following Mellanox recommendation:

``
[The proposed method] requires recent version of rdma-core and libiverbs [...]
Please note, the mlx5dv_ts_to_ns() is based on timestamps in CQE from kernel queues
and does not work in non-isolated mode (because DPDK catches all the traffic).
In 20.08 we are introducing the packet scheduling feature and it provides
the more reliable way to read the current device clock - read_clock() always
works if schedule sending is engaged and provides the clock data from the dedicated
clock queue without involving rdma_core or kernel.
``

* run without sudo (blocked by [smcroute](https://github.com/troglobit/smcroute/pull/112))
* For 64-bit applications, it is recommended to use [1 GB hugepages](https://doc.dpdk.org/guides/linux_gsg/sys_reqs.html#linux-gsg-hugepages)
* clang for bBPF compiling, maybe not necessary as we only join multicast we're interested in.
* explore `testpmd` options for optimization:
```
exple from the doc:
--burst=32 --rxfreet=32 --mbcache=250 --txpt=32 --rxht=8 --rxwt=0 --txfreet=32 --txrst=32

*   ``--burst=N``
    Set the number of packets per burst to N, where 1 <= N <= 512. The default value is 32.

*   ``--mbcache=N``
    Set the cache of mbuf memory pools to N, where 0 <= N <= 512.  The default value is 16.
*   ``--mp-alloc <native|anon|xmem|xmemhuge>``

    Select mempool allocation mode:
    * xmemhuge: create and populate mempool using externally and anonymously
      allocated hugepage area
```
