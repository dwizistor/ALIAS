#!/usr/bin/env bash

# Error handling and safe execution
set -o errexit
set -o nounset
set -o pipefail

# Branding ;)
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

# Logs
log_file="alias-install.log"
exec > >(tee -a "$log_file") 2>&1

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
groups="ftp,games,http,rfkill,audio,disk,input,storage,video,wheel"
swap_size="8G"

#- Bootloader
disk="/dev/nvme0n1"
kernel_params="mem_sleep_default=deep quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 reboot=acpi nowatchdog rcutree.enable_rcu_lazy=1"

#- Packages
base_packages=("base linux-lts linux-firmware e2fsprogs" "sof-firmware networkmanager nano man-db man-pages texinfo base-devel ntfs-3g sudo refind sbsigntools sbctl git rsync")
system_configuration_packages=("intel-ucode mesa vulkan-intel intel-media-driver vpl-gpu-rt libvpl" "nvidia-dkms nvidia-utils nvidia-prime" "vulkan-mesa-layers" "tlp ethtool smartmontools")
other_packages=("pamac-aur" "mpv" "ast-firmware wd719x-firmware linux-firmware-qlogic" "zen-browser-bin speech-dispatcher" "ark" "zswap-disable-writeback" "socat" "xorg-xhost" "stremio-enhanced-bin" "cloudflare-warp-bin" "visual-studio-code-bin" "fastfetch" "ayugram-desktop-bin" "gimp davinci-resolve audacity")

#- Modules
modules=("intel_agp i915")

# -----------------------------------------------------------------------------
# FUNCTIONS
# -----------------------------------------------------------------------------

# This function will confirm the user for exiting the script
quit() {
    echo -e "\n\n! WARNING : There might be unfavourable consequences of exiting the script in between.\n! Exiting in 5 seconds...\n  Press any key to cancel."
	read -r -N 1 -s -t 5 a && return 0 || exit 1
}

# This function will return true/false depending upon the key pressed.
skip_all=false
ask() {
    echo -e "\n\$ $1"
    read -N 1 -p "- Do you want to execute this line (y/n/s/q): " response
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

# Bootmode
liveboot="false"
is_chroot="false"

for arg in "$@"; do
    case $arg in
        --chroot)
        is_chroot="true"
        shift
        ;;
        *)
        shift
        ;;
    esac
done

echo ""
if [ ! -d "/sys/firmware/efi/efivars" ]; then
    echo "! UEFI not detected."
    quit
fi
if ! ping -c 1 -W 1 google.com >/dev/null; then
    echo "! No internet connection."
    quit
fi
if [ -d "/run/archiso" ]; then
  echo "- Live boot environment detected."
  liveboot="true"
else
  echo "- Non-live boot environment detected."
fi

# -----------------------------------------------------------------------------
# Live Boot environment
# -----------------------------------------------------------------------------
livevars(){
    packages_to_install=()
    packages_to_install+=(${base_packages[@]})
    packages_to_install+=(${system_configuration_packages[@]})

    commands=(
        "> Configuring time services"
        "timedatectl set-timezone $timezone"
        "hwclock --systohc"
        ########################################################
        "> Configuring pacman"
        "sed -i 's/#Color/Color/; /Color/aILoveCandy' /etc/pacman.conf"
        "sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf"
        "sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/' /etc/pacman.conf"
        "sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf"
        ########################################################
        "> Ranking mirrors"
        "reflector --latest 50 --sort rate --save /etc/pacman.d/mirrorlist"
        "cp -f mirrorlist /etc/pacman.d/mirrorlist"
        ########################################################
        "> Setting up partitions"
        "mkfs.ext4 $linpart"
        "tune2fs -O fast_commit $linpart"
        "mount $linpart /mnt"
        "mkdir /mnt/efi"
        ########################################################
        "> Backing up efi"
        "rm -rf efi_backup.img"
        "dd if='$efipart' of='efi_backup.img'"
        "mount $efipart /mnt/efi"
        ########################################################
        "> Installing linux"
        "pacman -Sy archlinux-keyring"
        "pacstrap -K /mnt ${packages_to_install[*]}"
        ########################################################
        "> Generating fstab"
        "genfstab -U /mnt >/mnt/etc/fstab"
        ########################################################
        "> Switching to chroot on /mnt"
        "cp -f /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist"
        "cp -f /etc/pacman.conf /mnt/etc/pacman.conf"
        "cp -f alias.bash /mnt/root/alias.bash"
        "arch-chroot /mnt /bin/bash /root/alias.bash --chroot"
        ########################################################
        "> Generating fstab"
        "partmnt"
        "genfstab -U /mnt >/mnt/etc/fstab"
        "sed -i '1,/relatime/ s/relatime/noatime,commit=60,barrier=0/' /mnt/etc/fstab"
        "echo -e '# SWAP\n/swapfile none swap defaults 0 0' >>/mnt/etc/fstab"
        ########################################################
        "> Configuring TLP"
        "cp -f tlp.conf /mnt/etc/tlp.conf"
        ########################################################
        "> Finished!"
    )
}

# -----------------------------------------------------------------------------
# Chroot environment
# -----------------------------------------------------------------------------
chrootvars(){
    commands=(
        "> Configuring time services"
        "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
        ########################################################
        "> Setting up locale and keymap"
        "sed -i 's/#$locale/$locale/' /etc/locale.gen ; echo 'LANG=$lang' > /etc/locale.conf ; echo 'KEYMAP=$keymap' > /etc/vconsole.conf ; echo 'FONT=$font' >> /etc/vconsole.conf ; locale-gen"
        ########################################################
        "> Cachy-ify"
        "curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz"
        "tar xvf cachyos-repo.tar.xz && cd cachyos-repo"
        "sudo ./cachyos-repo.sh"
        "cd .. && rm -rf cachyos-repo cachyos-repo.tar.xz"
        "sudo pacman -Syu linux-cachyos linux-cachyos-headers"
        "sudo pacman -Rcnsu linux-lts"
        "sudo mkinitcpio -P"
        "git clone --depth=1 https://github.com/CachyOS/CachyOS-Settings.git && cd CachyOS-Settings"
        "rm -rf etc/debuginfod usr/lib/modprobe.d/nvidia.conf usr/lib/modprobe.d/amdgpu.conf usr/lib/NetworkManager usr/lib/systemd/zram-generator.conf usr/lib/udev/rules.d/30-zram.rules usr/lib/udev/rules.d/50-sata.rules usr/share"
        "echo 'net.ipv4.tcp_fastopen = 3' | sudo tee -a usr/lib/sysctl.d/99-cachyos-settings.conf"
        "echo 'net.ipv4.tcp_timestamps = 0' | sudo tee -a usr/lib/sysctl.d/99-cachyos-settings.conf"
        "echo 'kernel.split_lock_mitigate=0' | sudo tee -a usr/lib/sysctl.d/99-cachyos-settings.conf"
        "sudo cp -rvf ./etc/. /etc"
        "sudo cp -rvf ./usr/. /usr"
        "sudo chmod +x /usr/bin/dlss-swapper-dll /usr/bin/zink-run /usr/bin/dlss-swapper /usr/bin/pci-latency"
        ########################################################
        "> Configuring network"
        "systemctl enable NetworkManager"
        ########################################################
        "> Configuring hosts"
        "echo '127.0.0.1 localhost' >> /etc/hosts"
        "echo '127.0.1.1 $machine' >> /etc/hosts"
        "echo '::1 localhost' >> /etc/hosts"
        "echo '$machine' > /etc/hostname"
        ########################################################
        "> Setting up root password and user and sudo"
        "passwd"
        "useradd -m $user"
        "passwd $user"
        "usermod -aG $groups $user"
        "echo 'Defaults timestamp_timeout = -1' > /etc/sudoers.d/01-alias"
        "sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"
        ########################################################
        "> Generating initramfs"
        "mkinitcpio -P"
        ########################################################
        "> Installing bootloader"
        "refind-install --usedefault $efipart"
        "efibootmgr --create --disk $disk --part 1 --loader /EFI/boot/bootx64.efi --label 'rEFInd' --verbose"
        ########################################################
        "> Configuring swap"
        "mkswap -U clear --size $swap_size --file /swapfile"
        ########################################################
        "> Adding perf tweaks"
        "systemctl enable fstrim.timer"
        "echo 'kernel.core_pattern=|/bin/false' >> /etc/sysctl.d/10-coredump.conf"
        "sed -i 's/-march=x86-64 -mtune=generic/-march=native -mtune=native/' /etc/makepkg.conf"
        "sed -i 's/#RUSTFLAGS=\"-C opt-level=2\"/RUSTFLAGS=\"-C opt-level=2 -C target-cpu=native\"/' /etc/makepkg.conf"
        "sed -i 's/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j20\"/' /etc/makepkg.conf"
        "sed -i \"s/#BUILDDIR=\/tmp\/makepkg/BUILDDIR=\/tmp\/makepkg/\" /etc/makepkg.conf"
        "sed -i \"s/PKGEXT='.pkg.tar.zst'/PKGEXT='.pkg.tar'/\" /etc/makepkg.conf"
        "echo 'options i915 enable_fbc=1' >> /etc/modprobe.d/i915.conf"
        "echo 'options i915 enable_psr=1' >> /etc/modprobe.d/i915.conf"
        "sed -i '/^HOOKS=/s/kms/systemd/' /etc/mkinitcpio.conf"
        "sed -i '/^HOOKS=/s/fsck/sd-vconsole/' /etc/mkinitcpio.conf"
        "sed -i 's/MODULES=()/MODULES=(${modules[*]})/' /etc/mkinitcpio.conf"
    )
}

# -----------------------------------------------------------------------------
# Booted environment
# -----------------------------------------------------------------------------
bootedvars() {
    packages_to_install=()
    packages_to_install+=(${other_packages[@]})

    offset=$(sudo filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
    linpartuuid=$(blkid -s UUID -o value $linpart)
    hiber="resume=UUID=$linpartuuid resume_offset=$offset"

    rfhook="[Trigger]
    Operation=Upgrade
    Type=Package
    Target=refind

    [Action]
    Description = Updating rEFInd on ESP
    When=PostTransaction
    Exec=/usr/bin/refind-install --usedefault $efipart"

    nvhook="[Trigger]
    Operation=Install
    Operation=Upgrade
    Operation=Remove
    Type=Package
    # You can remove package(s) that don't apply to your config, e.g. if you only use nvidia-open you can remove nvidia-lts as a Target
    Target=nvidia
    Target=nvidia-open
    Target=nvidia-lts
    # If running a different kernel, modify below to match
    Target=linux

    [Action]
    Description=Updating NVIDIA module in initcpio
    Depends=mkinitcpio
    When=PostTransaction
    NeedsTargets
    Exec=/bin/sh -c 'while read -r trg; do case \\\$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'"

    nvrules='# Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

    # Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
    ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"'

    commands=(
        "> Setting up clock"
        "timedatectl"
        "sudo hwclock -u -w"
        ########################################################
        "> Installing dots and packages"
        "bash <(curl -s https://ii.clsty.link/get)"
        "yay -Sy ${packages_to_install[*]}"
        "sudo systemctl enable warp-svc"
        "sudo systemctl start warp-svc"
        "warp-cli registration new"
        "warp-cli mode warp+doh"
		"git clone --depth=1 https://github.com/noelsimbolon/mpv-config"
		"mv -f mpv-config/* ~/.config/mpv/"
        "echo \"$nvrules\" | sudo tee -a /etc/udev/rules.d/80-nvidia-pm.rules"
        "cp -rf fastfetch ~/.local/share/"
        "echo \"fastfetch --config groups\" | tee -a ~/.config/fish/config.fish"
        "echo 'env = LIBVA_DRIVER_NAME,iHD' >> ~/.config/hypr/custom/env.conf"
        "echo 'env = VDPAU_DRIVER,va_gl' >> ~/.config/hypr/custom/env.conf"
        "echo 'env = ANV_VIDEO_DECODE,1' >> ~/.config/hypr/custom/env.conf"
        "echo 'env = AQ_DRM_DEVICES,/dev/dri/card1' >> ~/.config/hypr/custom/env.conf"
        "echo 'decoration:blur:enabled = false' >> ~/.config/hypr/custom/general.conf"
        "echo 'decoration:shadow:enabled = false' >> ~/.config/hypr/custom/general.conf"
        "echo 'misc:vfr = true' >> ~/.config/hypr/custom/general.conf"
        "echo 'misc:vrr = false' >> ~/.config/hypr/custom/general.conf"
        "sudo mkdir -p /etc/systemd/system/getty@tty1.service.d"
        "sudo cp -f autologin.conf /etc/systemd/system/getty@tty1.service.d/autologin.conf"
        "echo \"source ~/.config/fish/auto-Hypr.fish\" | tee -a ~/.config/fish/config.fish"
        "sudo systemctl enable --now fstrim.timer"
        "touch ~/.hushlogin"
#        "xhost si:localuser:root"
        "systemctl enable tlp.service"
        "mkdir -p ~/.config/wireplumber/wireplumber.conf.d"
        "cp -f 10-disable-camera.conf ~/.config/wireplumber/wireplumber.conf.d/10-disable-camera.conf"
        ########################################################
        "> Secure boot setup"
        "sudo sbctl create-keys"
        "sudo sbctl enroll-keys -m"
        "export ESP_PATH=/efi"
        "sudo mkdir -p /etc/refind.d/keys"
        "sudo cp /var/lib/sbctl/keys/db/db.key /etc/refind.d/keys/refind_local.key"
        "sudo cp /var/lib/sbctl/keys/db/db.pem /etc/refind.d/keys/refind_local.crt"
        "sudo refind-install --localkeys --usedefault $efipart"
        "sudo sbctl verify | sed 's/✗ /sudo sbctl sign -s /e'"
        "export ESP_PATH=/boot"
        "sudo sbctl verify | sed 's/✗ /sudo sbctl sign -s /e'"
        "sudo mkinitcpio -P"
        "echo \"$rfhook\" | sudo tee -a /etc/pacman.d/hooks/refind.hook > /dev/null"
        ########################################################
        "> reFind & Theme setup"
        "git clone --depth=1 https://github.com/AdityaGarg8/rEFInd-minimal-modded"
        "sed -i '/showtools shutdown/d' rEFInd-minimal-modded/theme.conf"
        "sudo rm -rf /efi/EFI/Boot/themes/*"
        "sudo mkdir -p /efi/EFI/Boot/themes"
        "sudo cp -rf rEFInd-minimal-modded /efi/EFI/Boot/themes/rEFInd-minimal"
        "sudo cp -f refind.conf /efi/EFI/Boot/"
        "sudo mkrlconf --force"
        "sudo sed -i '1s/\(UUID=[^\"]*\)\"/\1 $kernel_params $hiber\"/' /boot/refind_linux.conf"
        "sudo sed -i '1s/ro/rw/' /boot/refind_linux.conf"
        ########################################################
        "> Git config"
        "git config --global user.name \"$gitname\""
        "git config --global user.email \"$gitemail\""
        "git config --global core.editor \"nano\""
        ########################################################
        "> Auto refreshrate switch udev rule"
        "sudo cp -f 10-ChangeRefreshRate.rules /etc/udev/rules.d/10-ChangeRefreshRate.rules"
        "sudo cp -f ChangeRefreshRate.sh /usr/bin/ChangeRefreshRate.sh"
        "sudo chmod +x /usr/bin/ChangeRefreshRate.sh"
        ########################################################
        "> Enable nvidia services"
        "sudo systemctl enable nvidia-suspend.service"
        "sudo systemctl enable nvidia-resume.service"
        "sudo systemctl enable nvidia-hibernate.service"
        "echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=1' | sudo tee -a /etc/modprobe.d/nvi.conf"
        "echo 'options nvidia NVreg_TemporaryFilePath=/var/tmp' | sudo tee -a /etc/modprobe.d/nvi.conf"
        "echo 'options nvidia \"NVreg_DynamicPowerManagement=0x03\"' | sudo tee -a /etc/modprobe.d/nvi.conf"
        "echo 'options nvidia NVreg_UsePageAttributeTable=1' | sudo tee -a /etc/modprobe.d/nvi.conf"
        "echo 'options nvidia NVreg_InitializeSystemMemoryAllocations=0' | sudo tee -a /etc/modprobe.d/nvi.conf"
        "echo \"$nvhook\" | sudo tee -a /etc/pacman.d/hooks/nvidia.hook > /dev/null"
        ########################################################
    )
}

if [[ "$liveboot" == "true" ]] && [[ "$is_chroot" == "false" ]]; then
    livevars
elif [[ "$is_chroot" == "true" ]] then
    chrootvars
else
    bootedvars
fi

sync

partmnt() {
    mkdir -p /mnt/home/$user/drives
    chown -R 1000:1000 /mnt/home/$user/drives
    chmod -R 0765 /mnt/home/$user/drives
    for i in "${other_partitions[@]}"; do
        label=$(blkid -s LABEL /dev/$i | grep -Eo '"..*"' | sed 's/"//g')
        : ${label:="$i"}
        mkdir -p /mnt/home/$user/drives/$label
        mount -w /dev/$i /mnt/home/$user/drives/$label
    done
}

for command in "${commands[@]}"; do
    if [ "$skip_all" = true ]; then
        eval "$command"
    else
        case ${command:0:1} in
            ">") # Progress text
                echo -e "\n\n$command" ;; # Corrected echo -e for newline
            "-") # Execute directly
                eval "${command:2}" ;; # Corrected eval for command extraction
            *) # Execute with ask()
                ask "$command" && eval "$command" ;; # Corrected eval for command extraction
        esac
    fi
done

sync
