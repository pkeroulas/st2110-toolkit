## Hardware acceleration for transcoding

Proposed setup for hardware-accelerated scaling and encoding:

* GPU Model: Nvidia Quadro P4000
* GPU arch: Pascal GP104
* Centos: 7
* Kernel + header: 3.10
* Gcc: 4.8.5
* Glibc: 2.17
* CUDA Driver 10.1
* CUDA Runtime 10.0
* Nvidia driver: 418.43

### Nvidia driver

* [Linux driver installation guide.](https://linuxconfig.org/how-to-install-the-nvidia-drivers-on-centos-7-linux)
* [Download v415.18](https://www.nvidia.com/Download/driverResults.aspx/142958/en-us)

```sh
$ chmod 755 NVIDIA-Linux-x86_64-418.43.run
$ ./NVIDIA-Linux-x86_64-418.43.run -h
$ ./NVIDIA-Linux-x86_64-418.43.run -x
$ cd ./NVIDIA-Linux-x86_64-418.43
$ ./nvidia-installer # can --uninstall
```

Verify the driver is loaded:

```sh
$ lsmod | grep nvidia
$ cat /proc/driver/nvidia/version
$ ./nvidia-smi
```

[Complete install doc](http://http.download.nvidia.com/XFree86/Linux-x86_64/418.43/README/)

### CUDA SDK

* [Installation guide](https://developer.download.nvidia.com/compute/cuda/10.0/Prod/docs/sidebar/CUDA_Installation_Guide_Linux.pdf)
* [Download v10.0](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=CentOS&target_version=7&target_type=rpmnetwork)

Verify that CUDA can talk to GPU card:

```sh
~/cuda-10.0-samples/NVIDIA_CUDA-10.0_Samples/1_Utilities/deviceQuery/deviceQuery
[...]
Device 0: "Quadro P4000"
  CUDA Driver Version / Runtime Version          10.1 / 10.0
[...]
```

### Nvidia codec for ffmpeg:

`NVENC` needs for custom headers maintained outside of `ffmpeg` sources.

[ffmpeg doc for NVENC](https://trac.ffmpeg.org/wiki/HWAccelIntro#NVENC)

This is added in the install script.

## Measuring CPU and GPU utilization

```sh
$ vmstat -w -n 1 # check "us" (user) column
$ nvidia-smi dmon -i 0 # check "enc" column
```

### Troubleshoot

Got this message after ffmpeg version bumped:

```
[h264_nvenc @ 0x25d3440] Driver does not support the required nvenc API version. Required: 9.0 Found: 8.1
[h264_nvenc @ 0x25d3440] The minimum required Nvidia driver for nvenc is 390.25 or newer
```

Version doesn't seem to match anything but bumping the driver from 415 to 418 solved it.
