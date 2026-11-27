# Linux Installation

The LattePanda Sigma 2 is based on a standard x86 architecture processor, meaning the Linux installation process is identical to that of a regular laptop or desktop computer. It is fully compatible with most mainstream Linux distributions.

!!! note "Pre-installed Ubuntu OS"
    The 1TB SSD that ships with LattePanda Sigma 2 already has Ubuntu 26.04 LTS, GPU/NPU drivers and local AI models pre-installed. You only need this guide if you want to reinstall or install a different Linux distribution.

## Kernel Requirement

The Panther Lake platform requires a recent Linux kernel:

- **Recommended: Linux 7.0 or later** — shipped by default with **Ubuntu 26.04 LTS**, providing the complete support baseline for this platform, including targeted optimizations for the Xe3 integrated graphics and the NPU.
- **Minimum: Linux 6.17** — if you must stay on **Ubuntu 24.04 LTS**, use release 24.04.4 or later and install the HWE kernel stack (the factory 6.8 kernel does not properly support this platform); on a fully updated system this currently provides kernel 7.0:

    ```bash
    sudo apt update
    sudo apt install linux-generic-hwe-24.04
    ```

## General Installation Steps

1. **Download the Linux ISO**

    Visit the official website of your chosen Linux distribution and download the ISO image file. We recommend **Ubuntu 26.04 LTS (Desktop)**.

    [Click to Download Ubuntu Desktop](https://ubuntu.com/download/desktop)

2. **Create a Bootable USB Drive**

    Burn the downloaded ISO image to a USB flash drive. You can use tools like [**Rufus**](https://rufus.ie/) for this purpose.

3. **Boot from the USB Drive**

    Plug the bootable USB drive into your LattePanda Sigma 2, then power on or reboot. Immediately and repeatedly press the **++f7++** key to enter the Boot Device Selection Menu, select your USB flash drive, and press **++enter++**.

    !!! tip
        You can also press **++del++** to enter the BIOS setup and adjust the boot order there.

4. **Install the Operating System**

    Follow the on-screen instructions provided by the Linux installer to partition your M.2 SSD and complete the OS installation.

    !!! warning "Data Loss Warning"
        Installing a new OS will erase the pre-installed Ubuntu system and local AI models on the SSD. Please back up any data you need before proceeding.

5. **Post-Installation & Driver Updates**

    After the installation is complete, if you find that certain peripherals (such as Wi-Fi, Bluetooth, or audio) are not functioning properly, it is usually due to missing drivers in the default kernel.

    - **Update the System**: Run a full system update to fetch the latest packages.
    - **Upgrade the Kernel**: If issues persist, try upgrading to a newer Linux kernel, which often includes better support for newer hardware.
    - **Install Proprietary Drivers**: Some components may require proprietary drivers. Check your distribution's "Additional Drivers" utility.

!!! note
    The following driver installation procedures apply to both Ubuntu 24.04 and 26.04. Select the correct NPU driver package for your operating system.


## Intel GPU Compute Driver

Linux's default graphics drivers are only responsible for display output and do not include GPU compute libraries (OpenCL / Level Zero).

If you plan to run large language models locally (such as OpenVINO, llama.cpp) or perform other general-purpose GPU computing (such as PyTorch XPU or AI video processing), you need to install the official Intel compute runtime.

- [Click here for installation guide](https://dgpu-docs.intel.com/installation-guides/index.html)

## Intel NPU Drivers

- [Click here for installation guide](https://github.com/intel/linux-npu-driver/releases)


## Intel GPU Compute Driver

Linux's default graphics driver provides display output but does not include all the compute libraries required for GPU acceleration.

To run local AI models with OpenVINO, llama.cpp, or other GPU-accelerated applications, install Intel's GPU Compute Runtime.

### Step 1. Add the Intel Graphics PPA

Refresh the local package index and install the package for managing software repositories:

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common
```

Add the Intel Graphics PPA:

```bash
sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
```

Refresh the package index:

```bash
sudo apt-get update
```

### Step 2. Install GPU Compute Runtime

Install the required compute packages:

```bash
sudo apt-get install -y \
    libze-intel-gpu1 \
    libze1 \
    intel-metrics-discovery \
    intel-opencl-icd \
    clinfo \
    intel-gsc
```

These packages provide the main GPU compute components:

| Package | Description |
|---|---|
| `libze-intel-gpu1` | Intel GPU Level Zero implementation |
| `libze1` | Level Zero Loader |
| `intel-metrics-discovery` | GPU performance metrics support |
| `intel-opencl-icd` | Intel OpenCL runtime |
| `clinfo` | OpenCL device inspection utility |
| `intel-gsc` | Intel Graphics Security Controller support |

### Step 3. Configure User Permissions

GPU compute applications need access to the GPU render device.

Check the device nodes:

```bash
ls -l /dev/dri/
```

Check the current user's groups:

```bash
id -nG
```

If the `render` group is missing, add the current user:

```bash
sudo gpasswd -a "$USER" render
```

Log out and log in again, or reboot the system, to apply the group change.

### Step 4. Verify GPU Installation

Check the OpenCL platform and GPU device:

```bash
clinfo -l
```

For more detailed device information:

```bash
clinfo | grep "Device Name"
```

If the installation is successful, Intel graphics devices should be listed.

On the tested Sigma 2 configuration, the output included:

```text
Platform #0: Intel(R) OpenCL Graphics (integrated)
 `-- Device #0: Intel(R) Arc(TM) B390 GPU
```

<!-- Screenshot: clinfo -l output showing Intel Arc B390 -->

If no Intel GPU is listed, check the render device permissions:

```bash
ls -l /dev/dri/renderD*
id -nG
```

Make sure the current user belongs to the `render` group.

### Optional GPU Components

The following packages are optional and should only be installed when the corresponding functionality is required.

**Media Acceleration**

For hardware-accelerated video decoding and encoding:

```bash
sudo apt-get install -y \
    intel-media-va-driver-non-free \
    libmfx-gen1.2 \
    libvpl2 \
    libvpl-tools \
    libva-glx2 \
    va-driver-all \
    vainfo
```

**Ahead-of-Time (AoT) Compilation**

If you need to build SYCL or PyTorch applications from source, or precompile GPU kernels for specific devices, install:

```bash
sudo apt-get install -y libze-dev intel-ocloc
```

**Hardware Ray Tracing**

If your application requires hardware ray tracing support, install:

```bash
sudo apt-get install -y libze-intel-gpu-raytracing
```

## Intel NPU Drivers

The Intel NPU requires a separate driver package in addition to the GPU compute runtime.

This guide uses Intel Linux NPU Driver v1.39.1, which provides separate packages for Ubuntu 24.04 and Ubuntu 26.04.

Official release:

https://github.com/intel/linux-npu-driver/releases/tag/v1.39.1

### Step 1. Check Existing NPU Driver Packages

Check whether an older NPU driver is already installed:

```bash
dpkg -l | grep -E \
'intel-driver-compiler-npu|intel-fw-npu|intel-level-zero-npu'
```

If you are replacing an older NPU driver version, remove the existing NPU packages first:

```bash
sudo dpkg --purge --force-remove-reinstreq \
    intel-driver-compiler-npu \
    intel-fw-npu \
    intel-level-zero-npu \
    intel-level-zero-npu-dbgsym
```

Skip this removal step if no previous NPU driver is installed.

### Step 2. Download the NPU Driver Package

Create a working directory:

```bash
mkdir -p ~/npu-driver-v1.39.1
cd ~/npu-driver-v1.39.1
```

Select the package corresponding to your Ubuntu version.

=== "Ubuntu 24.04"

    ```bash
    wget https://github.com/intel/linux-npu-driver/releases/download/v1.39.1/linux-npu-driver-v1.39.1.20261119-44517102376-ubuntu2404.tar.gz

    tar -xf linux-npu-driver-v1.39.1.20261119-44517102376-ubuntu2404.tar.gz
    ```

=== "Ubuntu 26.04"

    ```bash
    wget https://github.com/intel/linux-npu-driver/releases/download/v1.39.1/linux-npu-driver-v1.39.1.20261119-44517102376-ubuntu2604.tar.gz

    tar -xf linux-npu-driver-v1.39.1.20261119-44517102376-ubuntu2604.tar.gz
    ```

### Step 3. Install Dependencies

Install `libtbb12`, which is required by `intel-driver-compiler-npu`:

```bash
sudo apt update
sudo apt install -y libtbb12
```

### Step 4. Install the NPU Driver Packages

From the directory containing the extracted `.deb` files, run:

```bash
sudo dpkg -i ./*.deb
```

### Step 5. Install the Matching Level Zero Loader

The NPU driver requires a compatible Level Zero Loader.

Download the `libze1` package matching your Ubuntu version.

=== "Ubuntu 24.04"

    ```bash
    wget https://snapshot.ppa.launchpadcontent.net/kobuk-team/intel-graphics/ubuntu/20261110T100000Z/pool/main/l/level-zero-loader/libze1_1.34.0-1~24.04~ppa1_amd64.deb

    sudo dpkg -i ./libze1_1.34.0-1~24.04~ppa1_amd64.deb
    ```

=== "Ubuntu 26.04"

    ```bash
    wget https://snapshot.ppa.launchpadcontent.net/kobuk-team/intel-graphics/ubuntu/20261110T100000Z/pool/main/l/level-zero-loader/libze1_1.34.0-1~26.04~ppa1_amd64.deb

    sudo dpkg -i ./libze1_1.34.0-1~26.04~ppa1_amd64.deb
    ```

!!! note
    Use the Level Zero Loader package matching your Ubuntu version. Do not mix the Ubuntu 24.04 and 26.04 packages.

### Step 6. Configure User Permissions

Add the current user to the `render` group:

```bash
sudo gpasswd -a "$USER" render
```

Check the group membership:

```bash
id -nG
```

The output should include `render`.

### Step 7. Reboot the System

Reboot to apply the driver and permission changes:

```bash
sudo reboot
```

### Step 8. Verify NPU Installation

After reboot, check whether the NPU device node exists:

```bash
ls -l /dev/accel/accel0
```

If the driver is initialized successfully, the device node should be present:

```text
/dev/accel/accel0
```

Check the NPU kernel driver messages:

```bash
sudo dmesg | grep -iE 'intel_vpu|NPU50xx'
```

On the tested Sigma 2 configuration, the log showed:

```text
intel_vpu 0000:00:0b.0: [drm] Firmware:
intel/vpu/vpu_50xx_v1.bin

[drm] Firmware version:
Oct 28 2026*NPU50xx*

[drm] Scheduler mode: HW

[drm] Initialized intel_vpu 1.0.0
```

<!-- Screenshot: NPU firmware loading and intel_vpu initialization in dmesg -->

Check the installed driver versions:

```bash
dpkg-query -W -f='${Package}\t${Version}\n' \
    intel-driver-compiler-npu \
    intel-fw-npu \
    intel-level-zero-npu \
    libze1
```

The tested configuration reported:

| Component | Installed Version |
|---|---|
| Intel NPU Driver | 1.39.1 |
| NPU Firmware | October 28, 2026 |
| Level Zero | 1.34.0 |

If `/dev/accel/accel0` is missing, check the kernel version, driver package installation, user permissions, and NPU initialization messages.

!!! note
    The Intel v1.39.1 release lists Panther Lake verification on Ubuntu 24.04 and 26.04 with kernel 7.0.0-38-generic. The Sigma 2 test in this guide used Ubuntu 26.04.1 with kernel 7.0.0-44-generic and successfully initialized the NPU driver.

## References

- Intel Graphics PPA Installation Guide: https://dgpu-docs.intel.com/installation-guides/installing-packages-from-the-intel-ppa.html
- Intel Linux NPU Driver Releases: https://github.com/intel/linux-npu-driver/releases

------

[**:simple-discord: Join our Discord**](https://discord.gg/k6YPYQgmHt){ .md-button .md-button--primary }
