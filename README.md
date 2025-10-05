<div align="center">
<picture>
  <img alt="ALIAS Logo" src="https://github.com/user-attachments/assets/f7f227bd-8b23-407b-992e-b13f5fc4a0a4" height="100px">
</picture>
</div>
<div align="center">ALIAS (ArchLinux Installation Automation Script)</div>

## ❓ FAQ
### 🤔 What are these scripts?
These scripts are for introducing automation to ArchLinux installations while maintaining a granular control over the components. It also helped me with getting a deeper understanding of operating systems.

### 🪓 What does the script do?
  - In Live Boot: Initial setup from the live ISO (partitioning, pacstrap, etc.).
  - In chroot: System configuration from within the arch-chroot environment.
  - In normal booted: Post-reboot customization and user-space setup (desktop environment, applications, etc.).

## 🛠️ Installation
### 🧠 Prerequisites
  1. An Arch Linux live ISO booted in UEFI mode.
  2. A working internet connection.
  3. Familiarity with the scripts' contents, as they are tailored for specific hardware and software choices.
### ⌨️ Run in live boot env:
  1. Make the scripts executable: chmod +x a.bash b.bash c.bash.
  2. Run the first script: ./a.bash.
  3. The script will guide you through the initial setup, chroot into the new system, and automatically execute b.bash.
  4. After b.bash completes and you exit the chroot, reboot the system.
  5. Once logged into your new user, run c.bash to complete the setup.

## 👽 Future Scope & To-Do List
- [x] Nvidia
- [ ] Disk Encryption
- [ ] You tell me.
