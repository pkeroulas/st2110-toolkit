# DPDK

[User guide and introduction.](https://doc.dpdk.org/guides/index.html)

## Getting stated

### Build

```sh
git clone https://github.com/DPDK/dpdk.git
cd dpdk
make defconfig
```

Apply following config (`./build/.config`):

```sh
CONFIG_RTE_LIBRTE_MLX5_PMD=y
CONFIG_RTE_LIBRTE_PMD_PCAP=y
CONFIG_RTE_LIBRTE_BPF_ELF=y
```

```sh
make
sudo make install
```

### NIC setup

```
iface=......
ethtool --set-priv-flags $iface sniffer on
ethtool -G $iface rx 8192
hwstamp_ctl -i $iface -r 1
```

### Execution

Primary process, read from eth driver and manage `pdump` server:

```sh
./build/app/testpmd -w 0000:01:00.0 -w 0000:01:00.1 -n4 -- --enable-rx-timestamp
```

Secondary process manages the `pdump` client and write to pcap file.

```sh
./build/app/dpdk-pdump -- --multi \
    --pdump 'port=0,queue=*,rx-dev=/tmp/test0.pcap' \
    --pdump 'port=1,queue=*,rx-dev=/tmp/test1.pcap' \
```

### Hardware timestamps

Raw timestamps are the captured values of the free running counter (one
for each ethernet port) and needs to converted into nanoseconds to fit
in pcap files and to satisfy the accuracy required by EBU-LIST analyzer.

2 methods for conversion:

|               | device frequency                                | HW clock info                                         |
|---------------|-------------------------------------------------|-------------------------------------------------------|
| **principle** | a device constant attribute that can be queried on startup | Use the converter implemented by Mellanox libiverbs `infiniband/mlxdv5.h` |
| **branch**    | https://github.com/pkeroulas/dpdk/tree/pdump_mlx5_hw_ts/v6 | https://github.com/pkeroulas/dpdk/tree/pdump_mlx5_hw_ts/clock_info/v1     |
| **pros**      | it is easy to implement, more acceptable for upstream contribution | **it just works**, with same precision as libvma |
| **cons**      | **accuracy as bad as SW timestamping** | clock info needs to be updated thanks to a timer + this **doesn't make a consensus in dpdk community**  `` S. Ovsiienko (Mellanox): "it requires recent version of rdma-core and libiverbs [...]  mlx5dv_get_clock_info() relies on timestamps of kernel queues, it might not work in DPDK non-isolated mode (DPDK takes all the traffic, kernel sees nothing)" `` |

### Filter

Builtin filters doesn't work for mlx5:

```sh
> 5tuple_filter 1 add dst_ip 225.192.10.1 src_ip 192.168.105.1 dst_port 20000 src_port 10000 protocol 17 mask 0x1F tcp_flags 0 priority 2 queue 2
ntuple filter is not supported on port 1
> flow_director_filter 0 mode IP add flow ipv4-udp src 192.168.105.1 10000 dst 225.192.10.1 20000 tos 0 ttl 255 vlan 1 flexbytes (0x88,0x48) fwd pf queue 1 fd_id 1
net_mlx5: mlx5_flow.c:5644: flow_fdir_ctrl_func(): port 0 flow director mode 0 not supported
```

The workaround is to supply `test-pmd` a compiled eBPF. `clang` `libc6-dev-i386` are required.

```
clang -O2 -I /usr/include/x86_64-linux-gnu/ -U __GNUC__ -target bpf -c ./bpf.c
testpmd> bpf-load rx 0 0 J ./bpf.o
```

## Dpdk-based 3rd party apps for captures

| Solutions   | Filter | Dual port | Pros   | Cons  | Source |
|-------------|--------|-----------|--------|-------|--------|
| builtin app | y | y | good for testing  | not the best for integration | https://doc.dpdk.org/guides/tools/pdump.html |
| tcpdump     | y | y | lots of features  | bad performances  |  https://github.com/the-tcpdump-group/libpcap |
| dpdk-dump   | n | y | simple | old doesn't build anymore | https://github.com/marty90/DPDK-Dump |
| PcapPlusPlus| y | y | ?      | complicated        | https://github.com/seladb/PcapPlusPlus/tree/master/Examples/DpdkExample-FilterTraffic |
| dpdkcap     | n | y | snaplen, realtime stats | ? | https://github.com/dpdkcap/dpdkcap.git |
| dpdk-pcapng | ? | ? | ? | ? | https://github.com/shemminger/dpdk-pcapng.git |

### Build

Ususally, dpdk-based apps needs the following variables:

```
cd ~/src/dpdk/examples/rxtx_callbacks
export RTE_SDK=/home/ebulist/src/dpdk
export RTE_TARGET=build
make
sudo ./examples/rxtx_callbacks/build/rxtx_callbacks -l 1 -n 4 -- -t
```

### Tcpdump:

Build:

* dpdk v20.05 config: ` CONFIG_RTE_BUILD_SHARED_LIB=y `
* libpcap 1.8.1 source to be located in same folder as `./tcpdump/`.  `./configure --with-dpdk=<ABSOLUTE_path_to_dpdk> `
* tcpdump:  `make` ( gcc  -DHAVE_CONFIG_H   -I. -I../libpcap  -g -O2  -o
  tcpdump fptype.o tcpdump.o  libnetdissect.a -lcrypto
  ../libpcap/libpcap.a -libverbs  -L/tmp/staging/usr/local/lib -ldpdk
  -lrt -lm -lnuma -ldl -pthread)

Exec:

```
sudo DPDK_CFG="--log-level=debug -dlibrte_mempool_ring.so -dlibrte_common_mlx5.so -dlibrte_pmd_mlx5.so ./tcpdump -i dpdk:0 --time-stamp-precision=nano -j adapter_unsynced dst port 20000
```

Results: 15% pkts dropped by interface. This is due to libcap that makes too many copies and syscalls and that should improve "soon" according to community.

### Solution

DPDK builtin utilities (testpmd and dpdk-pdump) are chosen for their versatily considering that the tunning might be a long process.
[This script](https://github.com/pkeroulas/st2110-toolkit/blob/dpdk/capture/master/dpdk-capture.sh) wraps the capture program in a tcpdump-like command line interpreter. The overhead induced by multiple process being started/stopped is not an issue in our use case.
[Custom dev_info/v1](https://github.com/pkeroulas/dpdk/tree/pdump_mlx5_hw_ts/clock_info/v1) is the only satisfying version so far.

## Performances

The following tools validate the resulting pcap file (duration, bitrate, TS accuracy, pkt drop, etc):

* [capinfos](https://www.wireshark.org/docs/man-pages/capinfos.html)
* [Packet drop detector](https://github.com/pkeroulas/st2110-toolkit/blob/master/misc/pkt_drop_detector.py)
* [Vrx validation](https://github.com/ebu/smpte2110-analyzer/blob/master/vrx_analysis.py)

| Bitrate in Gbps | Drop | Vrx | Comments |
|-----------------|------|-----|----------|
| 1.3 | ok | ok | 1080i video @ 60fps     |
| 5.2 | ok | ok | 2160p @ 30fps           |
| 6.5 | ok | ok | max on SSD              |
| 10  | ok | ok | need to write into RAM  |

## TODO

* run without sudo (blocked by [smcroute](https://github.com/troglobit/smcroute/pull/112))
* set a flag for ST2022-7 and merge pcap
* clang for bBPF compiling, maybe not necessary as we only join multicast we're interested in.
* explore `testpmd` options for optimization:
```
exple from the doc:
--burst=32 --rxfreet=32 --mbcache=250 --txpt=32 --rxht=8 --rxwt=0 --txfreet=32 --txrst=32

*   ``--burst=N``
    Set the number of packets per burst to N, where 1 <= N <= 512. The default value is 32.

*   ``--mbcache=N``
    Set the cache of mbuf memory pools to N, where 0 <= N <= 512.  The default value is 16.
```
