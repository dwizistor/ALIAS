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
Exec=/bin/sh -c 'while read -r trg; do case \$trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'"

sdwl='[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1'

refreshrules='# Rule for when switching to battery
ACTION=="change", SUBSYSTEM=="power_supply", ATTRS{type}=="Mains", ATTRS{online}=="0", RUN+="/usr/bin/ChangeRefreshRate.sh 60 &>/dev/null --machine=target_user@.host"
# Rule for when switching to AC
ACTION=="change", SUBSYSTEM=="power_supply", ATTRS{type}=="Mains", ATTRS{online}=="1", RUN+="/usr/bin/ChangeRefreshRate.sh 144 &>/dev/null --machine=target_user@.host"'

refreshscript='#!/usr/bin/env bash

MON="eDP-1"
RES="1920x1080"
SCA=1

for dir in /run/user/*; do
  for hypr_dir in "$dir/hypr/"*/; do
    socket="${hypr_dir}.socket.sock"
    if [[ -S $socket ]]; then
      echo -e "keyword monitor $MON,$RES@$1,0x0,$SCA" | socat - UNIX-CONNECT:"$socket"
    fi
  done
done'

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
    "sudo cp -f $wall /usr/share/sddm/themes/silent/backgrounds/smoky.jpg"
    "echo $sdwl >>/etc/sddm.conf.d/10-wayland.conf"
    "yay -S nvidia-prime nvidia-prime-rtd3pm"
    "sed -i '0,/scale = 1.0/s/scale = 1.0/scale = 1.5/' /usr/share/sddm/themes/silent/configs/default.conf"
    "sed -i 's/blur = [0-9]\+/blur = 100/g' /usr/share/sddm/themes/silent/configs/default.conf"
    "echo 'env = LIBVA_DRIVER_NAME,iHD' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = VDPAU_DRIVER,va_gl' >> ~/.config/hypr/custom/env.conf"
    "echo 'env = ANV_VIDEO_DECODE,1' >> ~/.config/hypr/custom/env.conf"
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
    "git clone --depth=1 https://github.com/killign/killign-rEFInd"
    "sudo mkdir -p /efi/EFI/Boot/themes"
    "sudo cp -rf killign-rEFInd /efi/EFI/Boot/themes/"
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
    "echo \'$refreshrules\' | sudo tee -a /etc/udev/rules.d/99-ChangeRefreshRate.rules"
    "echo \'$refreshscript\' | sudo tee -a /usr/bin/ChangeRefreshRate.sh"
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
