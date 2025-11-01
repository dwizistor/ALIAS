#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cat <<"EOF"
+---------------------------------------------+
|  Arch Linux Installation Automation Script  |
+---------------------------------------------+
|       <<<<<<<                 >>>>>>>       |
|      <:::::<                   >:::::>      |
|     <:::::<                     >:::::>     |
|    <:::::<                       >:::::>    |
|   <:::::<           -:-           >:::::>   |
|  <:::::<           -:::-           >:::::>  |
| <:::::<           -:::::-           >:::::> |
|  <:::::<         -:::::::-         >:::::>  |
|   <:::::<       -:::::::::-       >:::::>   |
|    <:::::<                       >:::::>    |
|     <:::::<                     >:::::>     |
|      <:::::<                   >:::::>      |
|       <<<<<<<                 >>>>>>>       |
+---------------------------------------------+
|                    ALIAS                    |
+---------------------------------------------+
EOF

# -----------------------------------------------------------------------------
# VARIABLES
# -----------------------------------------------------------------------------

#- User
user="dwizistor"
machine="AshLeg"
gitname="Avinash Dwivedi"
gitemail="141247046+dwizistor@users.noreply.github.com"

#- Disks
efipart="/dev/nvme0n1p1"
linpart="/dev/nvme0n1p5"
other_partitions=("nvme0n1p6" "nvme0n1p3")

#- System
timezone="Asia/Kolkata"
locale="en_IN"
lang="$locale.UTF-8"
keymap="us"
font="Lat2-Terminus16"
groups="ftp,games,http,audio,disk,storage,video,wheel"
swap_size="8G"
swappiness="35"
vfs_cache_pressure="50"

#- Pacman
paralleldownloads=4
reflector_latest=50
reflector_protocol="http,https"
reflector_sort="rate"

#- Bootloader
disk="/dev/nvme0n1"
kernel_params="pcie_aspm=force mem_sleep_default=deep quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 reboot=acpi nowatchdog"

#- Packages
base_packages=("base" "linux-lts" "linux-firmware" "e2fsprogs" "sof-firmware" "networkmanager" "nano" "man-db" "man-pages" "texinfo" "base-devel" "ntfs-3g" "sudo" "refind" "sbsigntools" "sbctl" "git")
system_configuration_packages=("intel-ucode" "mesa" "vulkan-intel" "intel-media-driver" "vpl-gpu-rt" "libvpl" "nvidia-lts" "nvidia-utils" "nvidia-prime" "vulkan-mesa-layers" "ethtool smartmontools")
other_packages=("pamac-aur" "mpv" "ast-firmware" "upd72020x-fw" "wd719x-firmware" "aic94xx-firmware" "linux-firmware-qlogic" "zed" "zen-browser-bin" "ark" "zswap-disable-writeback" "socat" "speech-dispatcher" "pipewire pipewire-pulse pavucontrol pipewire-audio" "xorg-xhost" "polkit-gnome")

#- Logging
log_file="alias-install.log"

#- Modules
modules=("intel_agp" "i915")

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

# This function will confirm the user for exiting the script
quit() {
    echo -e "\n! WARNING : There might be unfavourable consequences of exiting the script in between.\n! Exiting in 5 seconds...\n  Press any key to cancel."
	read -r -N 1 -s -t 5 a && return 0 || exit 1
}

# This function will return true/false depending upon the key pressed.
skip_all=false
ask() {
	echo -e "\n$1\n- Do you want to execute this line (y/n/s/q): "
    read -r -N 1 -s response
	case $response in
	n) return 1;;
	y) return 0;;
	s) skip_all=true; return 0;;
    q) quit;;
	*)
	    echo -e "! Invalid input\n"
	    ask $1
	esac
}

# This function will check if the script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "! This script must be run as root"
        exit 1
    fi
}

# This function will check if the system is booted in UEFI mode
check_uefi() {
    if [ ! -d "/sys/firmware/efi/efivars" ]; then
        echo "! System is not booted in UEFI mode"
        exit 1
    fi
}

# This function will check for internet connection
check_internet() {
    if ! ping -c 1 -W 1 google.com >/dev/null; then
        echo "! No internet connection"
        exit 1
    fi
}
