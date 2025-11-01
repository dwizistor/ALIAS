#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source init.bash

exec > >(tee -a "$log_file") 2>&1

packages_to_install=()
packages_to_install+=(${other_packages[@]})

offset=$(sudo filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
linpartuuid=$(blkid -s UUID -o value $linpart)
hiber="resume=UUID=$linpartuuid resume_offset=$offset"
wall="/home/dwizistor/drives/Files/_dotfiles/Wallpaper.png"

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

autolog=""

commands=(
    "> Setting up clock"
    "timedatectl"
    "sudo hwclock -u -w"
    ########################################################
    "> Installing dots and packages"
    "git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia"
    "fish ~/.local/share/caelestia/install.fish --aur-helper=yay --zen"
    "yay -Sy ${packages_to_install[*]}"
    "echo \"$nvrules\" | sudo tee -a /etc/udev/rules.d/80-nvidia-pm.rules"
    "echo 'env = LIBVA_DRIVER_NAME,iHD' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = VDPAU_DRIVER,va_gl' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = ANV_VIDEO_DECODE,1' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = AQ_DRM_DEVICES,/dev/dri/card1' >> ~/.config/hypr/custom/env.conf"
    "sudo mkdir -p /etc/systemd/system/getty@tty1.service.d"
    "sudo cp -f autologin.conf /etc/systemd/system/getty@tty1.service.d/autologin.conf"
    "cp -f uwsm-hypr.fish ~/.config/fish/uwsm-hypr.fish"
    "echo \"source ~/.config/fish/uwsm-hypr.fish\" | tee -a ~/.config/fish/config.fish"
    "sudo systemctl enable --now fstrim.timer"
    "touch ~/.hushlogin"
    "cp -f hypr-user.conf ~/.config/caelestia/hypr-user.conf"
    "cp -f shell.json ~/.config/caelestia/shell.json"
    "xhost si:localuser:root"
    "yay -Rdd 'power-profiles-daemon'"
    "yay -Syu tlp"
    "systemctl enable tlp.service"
    ########################################################
    "> Bluetooth"
    "yay -Syu bluez bluez-utils"
    "sudo systemctl enable bluetooth"
    "rfkill unblock bluetooth"
    "mkdir -p ~/.config/wireplumber/wireplumber.conf.d"
    "cp 10-disable-camera.conf ~/.config/wireplumber/wireplumber.conf.d/10-disable-camera.conf"
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
    "echo \"$nvhook\" | sudo tee -a /etc/pacman.d/hooks/nvidia.hook > /dev/null"
    ########################################################
    "> reFind Theme setup"
    "git clone --depth=1 https://github.com/AdityaGarg8/rEFInd-minimal-modded"
    "sed -i '/showtools shutdown/d' rEFInd-minimal-modded/theme.conf"
    "sudo rm -rf /efi/EFI/Boot/themes/*"
    "sudo mkdir -p /efi/EFI/Boot/themes"
    "sudo cp -rf rEFInd-minimal-modded /efi/EFI/Boot/themes/rEFInd-minimal"
    "sudo cp -f refind.conf /efi/EFI/Boot/"
    "sudo mkrlconf"
    "sudo sed -i '1s/\(UUID=[^\"]*\)\"/\1 $kernel_params $hiber\"/' /boot/refind_linux.conf"
    "sudo sed -i '1s/ro/rw/' /boot/refind_linux.conf"
    ########################################################
    "> Git config"
    "git config --global user.name \"$gitname\""
    "git config --global user.email \"$gitemail\""
    ########################################################
    "> Auto refreshrate switch udev rule"
    "sudo cp -f 99-ChangeRefreshRate.rules /etc/udev/rules.d/99-ChangeRefreshRate.rules"
    "sudo cp -f ChangeRefreshRate.sh /usr/bin/ChangeRefreshRate.sh"
    "sudo chmod +x /usr/bin/ChangeRefreshRate.sh"
    ########################################################
    "> Enable nvidia services"
    "sudo systemctl enable nvidia-suspend.service"
    "sudo systemctl enable nvidia-resume.service"
    "sudo systemctl enable nvidia-hibernate.service"
    "sudo systemctl enable nvidia-powerd"
    "echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=1' | sudo tee -a /etc/modprobe.d/nvi.conf"
    "echo 'options nvidia NVreg_TemporaryFilePath=/var/tmp' | sudo tee -a /etc/modprobe.d/nvi.conf"
    "echo 'options nvidia \"NVreg_DynamicPowerManagement=0x03\"' | sudo tee -a /etc/modprobe.d/nvi.conf"
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
