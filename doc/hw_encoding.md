## Hardware acceleration for transcoding

Proposed setup for hardware-accelerated scaling and encoding:

* GPU Model: Nvidia Quadro P4000
* GPU arch: Pascal GP104
* Centos: 7
* Kernel + header: 3.10
* Gcc: 4.8.5
* Glibc: 2.17
* CUDA: 10.0
* Nvidia driver: 415.18

### Nvidia driver

* [Linux driver installation guide.](https://linuxconfig.org/how-to-install-the-nvidia-drivers-on-centos-7-linux)
* [Download v415.18](https://www.nvidia.com/Download/driverResults.aspx/140282/en-us)

Verify the driver is loaded:

```sh
$  lsmod | grep nvi
nvidia_drm             39819  0
nvidia_modeset       1035536  1 nvidia_drm
nvidia_uvm            787278  2
nvidia              17251625  758 nvidia_modeset,nvidia_uvm
ipmi_msghandler        46607  2 ipmi_devintf,nvidia
drm_kms_helper        177166  2 vmwgfx,nvidia_drm
drm                   397988  5 ttm,drm_kms_helper,vmwgfx,nvidia_drm
[...]
$ cat /proc/driver/nvidia/version
[...]
$ nvidia-smi
[...]
```

### CUDA SDK

* [Installation guide](https://developer.download.nvidia.com/compute/cuda/10.0/Prod/docs/sidebar/CUDA_Installation_Guide_Linux.pdf)
* [Download v10.0](https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=CentOS&target_version=7&target_type=rpmnetwork)

Verify that CUDA can talk to GPU card:

```sh
~/cuda-10.0-samples/NVIDIA_CUDA-10.0_Samples/1_Utilities/deviceQuery/deviceQuery
[...]
Device 0: "Quadro P4000"
  CUDA Driver Version / Runtime Version          10.0 / 10.0
[...]
```

### Nvidia codec for ffmpeg:

`NVENC` needs for custom headers maintained outside of `ffmpeg` sources.

[ffmpeg doc for NVENC](https://trac.ffmpeg.org/wiki/HWAccelIntro#NVENC)
