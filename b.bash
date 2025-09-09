#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source init.bash

exec > >(tee -a "$log_file") 2>&1

# Array of commands
commands=(
    "> Configuring time services"
    "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
    ########################################################
    "> Configuring pacman"
    "sed -i 's/#Color/Color/' /etc/pacman.conf"
    "sed -i 's/#ParallelDownloads = 5/ParallelDownloads = $paralleldownloads/' /etc/pacman.conf"
    ########################################################
    "> Setting up locale and keymap"
    "sed -i 's/#$locale/$locale/' /etc/locale.gen ; echo 'LANG=$lang' > /etc/locale.conf ; echo 'KEYMAP=$keymap' > /etc/vconsole.conf ; echo 'FONT=$font' >> /etc/vconsole.conf ; locale-gen"
    ########################################################
    "> Configuring network"
    "systemctl enable NetworkManager"
    "echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.d/9-custom_sysctl.conf"
    "echo 'net.ipv4.tcp_timestamps = 0' >> /etc/sysctl.d/9-custom_sysctl.conf"
    "echo 'tcp_bbr' >> /etc/modules-load.d/modules.conf"
    "echo 'net.core.default_qdisc = cake' >> /etc/sysctl.d/9-custom_sysctl.conf"
    "echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.d/9-custom_sysctl.conf"
    ########################################################
    "> Configuring hosts"
    "echo '127.0.0.1 localhost' >> /etc/hosts"
    "echo '127.0.1.1 $machine' >> /etc/hosts"
    "echo '::1 localhost' >> /etc/hosts"
    "echo '$machine' > /etc/hostname"
    ########################################################
    "> Generating initramfs"
    "mkinitcpio -P"
    ########################################################
    "> Setting up root password and user"
    "passwd"
    "useradd -m $user"
    "passwd $user"
    "usermod -aG ${groups[*]} $user"
    ########################################################
    "> Installing bootloader"
    "refind-install --usedefault $efipart"
    "efibootmgr --create --disk $disk --part 1 --loader /EFI/boot/bootx64.efi --label 'rEFInd' --verbose"
    ########################################################
    "> Enable sudo"
    "echo 'Defaults timestamp_timeout = -1' > /etc/sudoers.d/01-alias"
    "sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers"
    ########################################################
    "> Configuring swap"
    "mkswap -U clear --size $swap_size --file /swapfile"
    "echo 'vm.swappiness = $swappiness' >/etc/sysctl.d/910-swap.conf"
    "echo 'vm.vfs_cache_pressure = $vfs_cache_pressure' >>/etc/sysctl.d/910-swap.conf"
    ########################################################
    "> Adding perf tweaks"
    "systemctl enable fstrim.timer"
    "echo 'kernel.core_pattern=|/bin/false' >> /etc/sysctl.d/50-coredump.conf"
    "echo 'vm.dirty_ratio = 2' >> /etc/sysctl.d/9-custom_sysctl.conf"
    "echo 'vm.dirty_background_ratio = 1' >> /etc/sysctl.d/9-custom_sysctl.conf"
    "echo 'dev.perf_stream_paranoid=0' >> /etc/sysctl.d/9-custom_sysctl.conf"
    "sed -i 's/-march=x86-64 -mtune=generic/-march=native -mtune=native/' /etc/makepkg.conf"
    "sed -i 's/#RUSTFLAGS=\"-C opt-level=2\"/RUSTFLAGS=\"-C opt-level=2 -C target-cpu=native\"/' /etc/makepkg.conf"
    "sed -i 's/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j14\"/' /etc/makepkg.conf"
    "sed -i \"s/#BUILDDIR=\/tmp\/makepkg/BUILDDIR=\/tmp\/makepkg/\" /etc/makepkg.conf"
    "sed -i \"s/PKGEXT='.pkg.tar.zst'/PKGEXT='.pkg.tar'/\" /etc/makepkg.conf"
    "echo 'options i915 enable_fbc=1' >> /etc/modprobe.d/i915.conf"
    "echo 'options i915 enable_psr=1' >> /etc/modprobe.d/i915.conf"
    "sed -i '/^HOOKS=/s/\s*kms resume\s*//' /etc/mkinitcpio.conf"
    "sed -i 's/MODULES=()/MODULES=(${modules[*]}})/' /etc/mkinitcpio.conf"
    "systemctl enable tlp.service"
)

for command in "${commands[@]}"; do
    if [ "$skip_all" = true ]; then
        eval "$command"
    else
        case ${command:0:1} in
            ">") # Progress text
                echo -e "$command" ;;
            "-") # Execute directly
                eval "${command:2}" ;;
            *) # Execute with ask()
                ask "$command" && eval "$command" ;;
        esac
    fi
done
