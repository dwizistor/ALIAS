#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source init.bash

exec > >(tee -a "$log_file") 2>&1

check_root
check_uefi
check_internet

packages_to_install=()
packages_to_install+=(${base_packages[@]})
packages_to_install+=(${system_configuration_packages[@]})

# Array of commands
declare -a commands=(
    "> Configuring time services"
    "timedatectl set-timezone $timezone"
    "timedatectl"
    "hwclock --systohc"
    ########################################################
    "> Configuring pacman"
    "sed -i 's/#Color/Color/; /Color/aILoveCandy' /etc/pacman.conf"
    "sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf"
    "sed -i 's/#ParallelDownloads = 5/ParallelDownloads = $paralleldownloads/' /etc/pacman.conf"
	"sed -i '/^#\[multilib\]/,+1 s/^#//' /etc/pacman.conf"
    ########################################################
    "> Ranking mirrors"
    "reflector --latest $reflector_latest --protocol $reflector_protocol --sort $reflector_sort --save /etc/pacman.d/mirrorlist"
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
    "cp -f b.bash /mnt/root/b.bash"
    "arch-chroot /mnt /bin/bash -c /root/b.bash"
    ########################################################
    "> Configuring TLP"
    "cp -f tlp.conf /mnt/etc/tlp.conf"
    ########################################################
    "> Generating fstab"
    "partmnt"
    "genfstab -U /mnt >/mnt/etc/fstab"
    "sed -i '1,/relatime/ s/relatime/noatime,commit=60,barrier=0/' /mnt/etc/fstab"
    "echo -e '# SWAP\n/swapfile none swap defaults 0 0' >>/mnt/etc/fstab"
    ########################################################
    "> Finished!"
)

sync

partmnt() {
    mkdir -p /mnt/home/$user/drives
    chown -R 1000:1000 /mnt/home/$user/drives
    chmod -R 0765 /mnt/home/$user/drives
    for i in "${other_partitions[@]}"; do
        label=$(blkid -s LABEL /dev/$i | grep -Eo '"..*"' | sed 's/"//g')
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
                echo -e "$command" ;; # Corrected echo -e for newline
            "-") # Execute directly
                eval "${command:2}" ;; # Corrected eval for command extraction
            *) # Execute with ask()
                ask "$command" && eval "$command" ;; # Corrected eval for command extraction
        esac
    fi
done
