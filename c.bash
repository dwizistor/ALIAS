#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source init.bash

exec > >(tee -a "$log_file") 2>&1

packages_to_install=()
packages_to_install+=(${other_packages[@]})

offset=$(filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
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
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'"

commands=(
    "> Setting up clock"
    "timedatectl"
    "sudo hwclock -u -w"
    ########################################################
    "> Installing dots and packages"
    "bash <(curl -s "https://end-4.github.io/dots-hyprland-wiki/setup.sh")"
    "yay -Sy ${packages_to_install[*]}"
    "sudo systemctl enable sddm"
    "git clone -b main --depth=1 https://github.com/uiriansan/SilentSDDM && cd SilentSDDM && ./install.sh"
    "echo 'env = LIBVA_DRIVER_NAME,iHD' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = VDPAU_DRIVER,va_gl' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = ANV_VIDEO_DECODE,1' >> ~/.config/hypr/custom/env.conf"
#    "sudo envycontrol -s hybrid --rtd3"
#    "sudo envycontrol --cache-create"
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
#    "echo \"$nvhook\" | sudo tee -a /etc/pacman.d/hooks/nvidia.hook > /dev/null"
    ########################################################
    "> reFind Theme setup"
    "git clone --depth=1 https://github.com/killign/killign-rEFInd"
    "sudo mkdir -p /efi/EFI/Boot/themes"
    "sudo cp -rf killign-rEFInd /efi/EFI/Boot/themes/"
    "sudo cp -f refind.conf /efi/EFI/Boot/"
    "sudo mkrlconf"
    "sudo sed -i '1s/\(UUID=[^\"]*\)\"/\1 $kernel_params $hiber\"/' /boot/refind_linux.conf"
    "sudo sed -i '1s/ro/rw/' /boot/refind_linux.conf"
    ########################################################
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
