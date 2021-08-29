# Arch-setup

A single file and fully customizable installer script for archlinux.

Archlinux is a distro that it gives full control to anyone who wants to install this distro. With their comprehensive [wiki page](https://wiki.archlinux.org/), one can find satisfying answers to his/her questions and can follow various guides to achieve his/her customized installation. By writing this script, I wanted to retain this customizability while on the other hand automating my installation process.

## Features

*It provides a complete system installation which can be boiled down to:*

- Auto partitioning

- Auto encrypting with cryptsetup ([LVM on LUKS](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS))

- Installing a set of packages (both aur and official)

- Performing package specific operations

- Installing an aur helper

- Installing a bootloader

- Installing a login manager & greeter

- Adding a user account

Also sets a default background for the desktop and login manager.

## Usage

After booting into the iso:

- Set your [keyboard layout](https://wiki.archlinux.org/title/Installation_guide#Set_the_keyboard_layout)

- Download git with `pacman -S git`

- Clone the repo with `git clone https://github.com/The-Plottwist/Arch-setup`

- Change your directory to `Arch-setup` (This is necessary for background images)

- Run the script with `./arch-setup.sh`

***A proper internet connection is needed!***

If you have a wired connection, just type `dhcpcd` and `ping archlinux.org -c 1`

Otherwise follow this guide: <https://www.linuxandubuntu.com/home/how-to-setup-a-wifi-in-arch-linux-using-terminal>

## Why a bash script?

A large proportion of the linux users are already familiar with bash and it doesn't need to compile.

## Followed Guides

- <https://wiki.archlinux.org/title/Installation_guide>

- <https://wiki.archlinux.org/title/EFI_system_partition#Create_the_partition>

- <https://wiki.archlinux.org/title/EFI_system_partition#Typical_mount_points> (Option three)

- <https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS>
