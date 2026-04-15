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
groups="games,uucp,wheel"
swap_size="8G"

#- Bootloader
disk="/dev/nvme0n1"
kernel_params="quiet loglevel=3 systemd.show_status=auto rd.udev.log_level=3 vt.global_cursor_default=0 mem_sleep_default=deep nowatchdog rcutree.enable_rcu_lazy=1 reboot=acpi fbcon=nodefer"

#- Packages
base_packages=("base linux linux-firmware e2fsprogs" "networkmanager iwd micro man-db man-pages texinfo base-devel ntfs-3g sudo git rsync")
system_configuration_packages=("vulkan-mesa-layers")
other_packages=("cosmic gnome-keyring cosmic-ext-applet-caffeine-git cosmic-ext-tweaks-git bluez" "pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber" "zswap-disable-writeback fastfetch power-profiles-daemon" "cloudflare-warp-bin visual-studio-code-bin gimp audacity anydesk-bin handbrake")

#- Modules
modules="intel_agp,i915,ext4"

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
           echo -e "\n! Invalid input\n"
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
# System Configuration
# -----------------------------------------------------------------------------

if [[ ! -d "/sys/firmware/efi/efivars" ]] && [[ "$liveboot" == "true" ]] && [[ "$is_chroot" == "false" ]]; then
    echo "> Backing up efi"
    rm -rf efi_backup.img
    dd if='$efipart' of='efi_backup.img'
    mount $efipart /mnt/efi
    echo "! Setting up EFI boot packages."
    base_packages+=("booster systemd-ukify sbsigntools sbctl efibootmgr")
elif [[ ! -d "/sys/firmware/efi/efivars" ]] && [[ "$liveboot" == "true" ]] && [[ "$is_chroot" == "true" ]]; then
    command+=("> Installing EFISTUB"
        "echo 'rw root=UUID=$linpartuuid $kernel_params $hiber' | tee -a /etc/kernel/cmdline"
        "mkdir -p /etc/pacman.d/hooks"
        "cp -rf uki.hook /etc/pacman.d/hooks/uki.hook"
        "mkdir /efi/EFI/Linux"
        "ukify build --linux=/boot/vmlinuz-linux-cachyos --initrd=/boot/intel-ucode.img --initrd=/boot/booster-linux-cachyos.img --cmdline=\"$(cat /etc/kernel/cmdline)\" --output=/efi/EFI/Linux/arch-linux.efi"
        "efibootmgr --create --disk /dev/nvme0n1 --part 1 --label \"Arch Linux\" --loader /EFI/Linux/arch-linux.efi"
        "> Secure boot setup"
        "sbctl create-keys"
        "sbctl enroll-keys -m"
        "export ESP_PATH=/efi"
        "sbctl verify | sed -E 's|^.* (/.+) is not signed$|sbctl sign -s \"\\1\"|e'"
        "sbctl sign -s /efi/EFI/Linux/arch-linux.efi")
fi

if lspci | grep -i nvidia > /dev/null; then
    echo "! Nvidia GPU detected."
    nvi=true
    system_configuration_packages+=("nvidia-open-dkms nvidia-utils nvidia-prime") 
fi

if lscpu | grep "Vendor ID:" | grep -q "GenuineIntel"; then
    echo "! Intel CPU detected."
    system_configuration_packages+=("intel-ucode mesa vulkan-intel intel-media-driver vpl-gpu-rt libvpl sof-firmware") 
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
        "ghostmirror -Po -c India,Germany,France,\"United States\",Singapore -l ./mirrorlist.new -L 30 -S state,outofdate,morerecent,ping"
        "ghostmirror -Po -mu ./mirrorlist.new -l ./mirrorlist.new -s light -S state,outofdate,morerecent,estimated,speed"
        "cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak"
        "cp ./mirrorlist.new /etc/pacman.d/mirrorlist"
        "cp -f mirrorlist /etc/pacman.d/mirrorlist"
        ########################################################
        "> Setting up partitions"
        "mkfs.ext4 $linpart"
        "tune2fs -O fast_commit $linpart"
        "mount $linpart /mnt"
        "mkdir /mnt/efi"
        ########################################################
        "> Installing linux"
        "pacman -Sy archlinux-keyring"
        "pacstrap -K /mnt ${packages_to_install[*]}"
        ########################################################
        "> Generating fstab and swapfile"
        "mkswap -U clear --size $swap_size --file /mnt/swapfile"
        "genfstab -U /mnt >/mnt/etc/fstab"
        ########################################################
        "> Copying configured files"
        "cp -f /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist"
        "cp -f /etc/pacman.conf /mnt/etc/pacman.conf"
        "mkdir /etc/systemd/resolved.conf.d"
        "cp -f dns.conf /mnt/etc/systemd/resolved.conf.d/dns.conf"
        "ln -sf /mnt/run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf"
        ########################################################
        "> Switching to chroot on /mnt"
        "cp -rf ./ /mnt/root/"
        "arch-chroot /mnt /bin/bash /root/alias.bash --chroot"
        ########################################################
        "> Generating fstab"
        "partmnt"
        "genfstab -U /mnt >/mnt/etc/fstab"
        "sed -i '1,/relatime/ s/relatime/noatime,commit=60,barrier=0/' /mnt/etc/fstab"
        "echo -e '# SWAP\n/swapfile none swap defaults 0 0' >>/mnt/etc/fstab"
        ########################################################
        "> Finished!"
    )
}

# -----------------------------------------------------------------------------
# Chroot environment
# -----------------------------------------------------------------------------
chrootvars(){
    linpartuuid=$(blkid -s UUID -o value $linpart)
    offset=$(sudo filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
    hiber="resume=UUID=$linpartuuid resume_offset=$offset"

    commands=(
        "> Configuring time services"
        "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
        ########################################################
        "> Setting up locale and keymap"
        "sed -i 's/#$locale/$locale/' /etc/locale.gen ; echo 'LANG=$lang' > /etc/locale.conf ; echo 'KEYMAP=$keymap' > /etc/vconsole.conf ; echo 'FONT=$font' >> /etc/vconsole.conf ; locale-gen"
        ########################################################
        "> Booster config"
        "echo -e 'strip: true\nmodules_force_load: $modules\nuniversal: true' | tee -a /etc/booster.yaml" # Ensure first boot
        ########################################################
        "> Cachy-ify"
        "curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz"
        "tar xvf cachyos-repo.tar.xz && cd cachyos-repo"
        "./cachyos-repo.sh"
        "cd .. && rm -rf cachyos-repo cachyos-repo.tar.xz"
        "pacman -Syu linux-cachyos linux-cachyos-headers"
        "pacman -Rcnsu linux"
        "git clone --depth=1 https://github.com/CachyOS/CachyOS-Settings.git && cd CachyOS-Settings"
        "rm -rf etc/debuginfod usr/lib/modprobe.d/nvidia.conf usr/lib/systemd/zram-generator.conf usr/lib/udev/rules.d/30-zram.rules usr/lib/udev/rules.d/71-nvidia.rules usr/share"
        "echo 'net.ipv4.tcp_fastopen = 3' | sudo tee -a usr/lib/sysctl.d/70-cachyos-settings.conf"
        "echo 'net.ipv4.tcp_timestamps = 0' | sudo tee -a usr/lib/sysctl.d/70-cachyos-settings.conf"
        "echo 'kernel.split_lock_mitigate=0' | sudo tee -a usr/lib/sysctl.d/70-cachyos-settings.conf"
        "cp -rvf ./etc/. /etc"
        "cp -rvf ./usr/. /usr"
        "systemctl enable pci-latency.service cachyos-iw-set-regdomain.service"
        "chmod +x /usr/bin/dlss-swapper-dll /usr/bin/zink-run /usr/bin/dlss-swapper /usr/bin/pci-latency"
        ########################################################
        "> Configuring network"
        "systemctl enable NetworkManager"
        "systemctl enable systemd-resolved"
        "systemctl enable iwd.service"
        "systemctl disable wpa_supplicant.service"
        "systemctl disable wpa_supplicant@wlan0.service"
        "systemctl disable wpa_supplicant-nl80211@.service"
        "systemctl disable wpa_supplicant-wired@.service"
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
        "> Adding perf tweaks"
        "systemctl mask systemd-tpm2-setup.service systemd-tpm2-setup-early.service"
        "systemctl enable fstrim.timer"
        "echo 'kernel.core_pattern=|/bin/false' >> /etc/sysctl.d/10-coredump.conf"
        "sed -i 's/-march=x86-64 -mtune=generic/-march=native -mtune=native/' /etc/makepkg.conf"
        "sed -i 's/#RUSTFLAGS=\"-C opt-level=2\"/RUSTFLAGS=\"-C opt-level=2 -C target-cpu=native\"/' /etc/makepkg.conf"
        "sed -i 's/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j20\"/' /etc/makepkg.conf"
        "sed -i \"s/#BUILDDIR=\/tmp\/makepkg/BUILDDIR=\/tmp\/makepkg/\" /etc/makepkg.conf"
        "sed -i \"s/PKGEXT='.pkg.tar.zst'/PKGEXT='.pkg.tar'/\" /etc/makepkg.conf"
        "echo 'options i915 enable_fbc=1' >> /etc/modprobe.d/i915.conf"
        "echo 'options i915 enable_psr=1' >> /etc/modprobe.d/i915.conf"
    )
}

# -----------------------------------------------------------------------------
# Booted environment
# -----------------------------------------------------------------------------
bootedvars() {
    packages_to_install=()
    packages_to_install+=(${other_packages[@]})

    commands=(
        "> Setting up clock"
        "timedatectl"
        "sudo hwclock -w"
        ########################################################
        "> Installing packages and desktop env"
        "yay -Sy ${packages_to_install[*]}"
        "sudo systemctl enable cosmic-greeter.service"
        "cp -rf fastfetch ~/.local/share/"
        "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
        "echo \"fastfetch --config groups\" | tee -a ~/.zshrc"
        "echo 'SSH_AUTH_SOCK=\$XDG_RUNTIME_DIR/gcr/ssh' | tee -a ~/.zshrc"
        "sudo systemctl enable --now fstrim.timer"
        "sudo chmod 4755 /usr/lib/polkit-1/polkit-agent-helper-1" #Fix for automatic authentication fail on polkit
        "sudo systemctl --user enable --now gcr-ssh-agent.socket"
        "touch ~/.hushlogin"
        "sudo ln -s ~/drives/Files /D:" #Allows me to share same browser profile folder across both OS.
        "cp -rf powersave.sh /usr/local/bin/"
        "cp -rf powersave-custom.service /etc/systemd/system/"
        "sudo systemctl enable powersave-custom.service"
        ########################################################
        "> Git config"
        "git config --global user.name \"$gitname\""
        "git config --global user.email \"$gitemail\""
        "git config --global core.editor \"micro\""
        ########################################################
    )
}

if [[ "$liveboot" == "true" ]] && [[ "$is_chroot" == "false" ]]; then
    livevars
elif [[ "$is_chroot" == "true" ]] then
    chrootvars
else
    bootedvars
    if [[ "$nvi" == "true" ]] then;
        commands+=(
            "> Enable nvidia services"
            "sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service"
            "sudo systemctl disable nvidia-persistenced"
            "sudo cp -f nvi.conf /etc/modprobe.d/nvi.conf"
            "sudo mv /usr/share/glvnd/egl_vendor.d/{10,90}_nvidia.json"
            "cp -rf nvi.hook /etc/pacman.d/hooks/nvi.hook"
            "sed -n 'p' force_intel.sh > ~/.profile"
            "sudo cp -rf nvrun /usr/local/bin/"
            "sudo chmod +x /usr/local/bin/nvrun"
            "sudo cp -rf 80-nvidia-pm.rules /etc/udev/rules.d/80-nvidia-pm.rules"
            "sudo cp -rf nvidia-power-control.service /etc/systemd/system/nvidia-power-control.service"
            "sudo systemctl enable nvidia-power-control"
            "sudo mkdir /etc/systemd/system/nvidia-resume.service.d"
            "sudo cp -rf restore-pm.conf /etc/systemd/system/nvidia-resume.service.d/restore-pm.conf")
   fi
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
                ask "$command" && echo " " && eval "$command" ;; # Corrected eval for command extraction
        esac
    fi
done

sync
