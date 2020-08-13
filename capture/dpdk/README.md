# DPDK

[User guide](https://doc.dpdk.org/guides/index.html)

## build

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

## builtin app for captures

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

### hardware timestamps

dev_clock info requires recent version of rdma-core and libiverbs.

### filter

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

## dpdk-based 3rd party apps for captures

| *Solutions* | *Filter* | *Dual port* | *Others* | *Source* |
| builtin app | O | X | not easy to use | https://doc.dpdk.org/guides/tools/pdump.html |
| tcpdump     | O | O | bad performance  | https://github.com/marty90/DPDK-Dump |
| dpdk-dump   | X | O | old, doesn't build | https://github.com/marty90/DPDK-Dump |
| PcapPlusPlus| O | O | complicated        | https://github.com/seladb/PcapPlusPlus/tree/master/Examples/DpdkExample-FilterTraffic |
| dpdkcap     | X | O | snaplen, realtime stats | https://github.com/dpdkcap/dpdkcap.git |
| dpdk-pcapng | ? | ? | | https://github.com/shemminger/dpdk-pcapng.git |

### build

Ususally, dpdk-based apps needs the following variables:

```
cd ~/src/dpdk/examples/rxtx_callbacks
export RTE_SDK=/home/ebulist/src/dpdk
export RTE_TARGET=build
make
sudo ./examples/rxtx_callbacks/build/rxtx_callbacks -l 1 -n 4 -- -t
```

### tcpdump:

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

Result:

15% pkts dropped by interface. This is due to libcap that makes too many copies and syscalls and that should improve "soon" according to community.

## Tunning

```
ethtool --set-priv-flags $iface sniffer on
ethtool -G $iface rx 8192
hwstamp_ctl -i $iface -r 1
```

## Quality control:

```sh
capinfos /tmp/test.pcap
```

[Packet drop detector](https://github.com/pkeroulas/st2110-toolkit/blob/master/misc/pkt_drop_detector.py)
[Vrx validation](https://github.com/ebu/smpte2110-analyzer/blob/master/vrx_analysis.py)

## Performance

version dev_info/v1:

|*Bitrate in Gbps*|*Drop*|*Vrx*|
|-----------------|------|-----|
| 2.6 | ok | ok |
| 3.9 | ok | ok |
| 5.2 | ok | ok |
| 6.5 | ok | ok | <----- max on disk
| 10  | ok | ok | <----- need to write into RAM

testpmd options to explore:
```
exple:
--burst=32 --rxfreet=32 --mbcache=250 --txpt=32 --rxht=8 --rxwt=0 --txfreet=32 --txrst=32

*   ``--burst=N``
    Set the number of packets per burst to N, where 1 <= N <= 512. The default value is 32.

*   ``--mbcache=N``
    Set the cache of mbuf memory pools to N, where 0 <= N <= 512.  The default value is 16.
```

## TODO

* without sudo, blocked by [smcroute](https://github.com/troglobit/smcroute/pull/112)
* document HW timestamping story
* set a flag for -7 and merge pcap
* clang for bBPF compiling, maybe not necessary as we only join
  multicast we're interested in.
