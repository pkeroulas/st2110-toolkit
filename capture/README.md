# Capture


## Nvidia/Mellanox software

[OpenFabric OFED driver](https://docs.nvidia.com/networking/display/MLNXOFEDv461000/Release+Notes)
is no more supported but everything needed for a good RDMA-accelerated packet capture is now
included in Ubuntu packages: `rdma-core`, `libibverbs` and `mft`.

## DPDK-based capture engine

[DPDK page](https://github.com/pkeroulas/st2110-toolkit/blob/master/capture/dpdk/README.md).


## Various tools

The following scripts were just helpers when epxerimenting with SDP, NIC setup, multicast joining and basic capture.

* `nic_setup.sh`
* `./get_sdp.py`
* `./network_setup.sh`
* `./capture.sh`

## [Troubleshoot](../doc/troubleshoot.md)
