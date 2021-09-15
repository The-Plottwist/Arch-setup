# Arch-setup

A single and fully customizable installer script for archlinux.

Archlinux is a distro that it gives full control to anyone who wants to install this distro. With their comprehensive [wiki page](https://wiki.archlinux.org/), one can find satisfying answers to his/her questions and can follow various guides to achieve his/her customized installation. By writing this script, I wanted to retain this customizability while on the other hand automating my installation process.

## Features

*It provides a complete system installation which can be boiled down to:*

- Auto partitioning [[disabled by default](#how-to-enable-auto-partitioningencrypting)]

- Auto encrypting with [cryptsetup](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS) [[disabled by default](#how-to-enable-auto-partitioningencrypting)]

- Installing a set of packages (both aur and official)

- Performing package specific operations

- Installing an aur helper

- Installing a bootloader

- Installing a Desktop Environment

- Installing a login manager & greeter

- Setting a default background for desktop & login manager

- Adding a user account

- And a few more...

All of the packages are predefined and can be changed before running the script.
For more information, visit my [Packages](https://github.com/The-Plottwist/Arch-setup/blob/main/Packages.md) manual.

## Usage

*Script won't work if you don't have an active internet connection.*

**Enabling Internet Connection:**

- If you have a wired connection, just type `dhcpcd` and test it with `ping archlinux.org -c 1`

- Otherwise follow this guide: <https://www.linuxandubuntu.com/home/how-to-setup-a-wifi-in-arch-linux-using-terminal>

**Cloning the Repository:**

- Install git with `pacman -S git`

- Clone the repo with `git clone https://github.com/The-Plottwist/Arch-setup`

- Change your directory with `cd Arch-setup` (This is necessary for background images)

- Run the script with `./arch-setup.sh`

## How to enable auto partitioning/encrypting?

In the script, change this:

```bash
24 #Auto partitioning wipes hard disk entirely, therefore it is disabled by default.
25 #To enable, uncomment the below line
26 #Remember, it is at your own risk!
27 #declare ENABLE_AUTO_PARTITIONING="true"
```

 to this:

```bash
24 #Auto partitioning wipes hard disk entirely, therefore it is disabled by default.
25 #To enable, uncomment the below line
26 #Remember, it is at your own risk!
27 declare ENABLE_AUTO_PARTITIONING="true"
```

## How to modify the code?

You can read my manuals: [Breaking into pieces](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md) and [Before altering](https://github.com/The-Plottwist/Arch-setup/blob/main/Before-altering.md).
Rest is up to you.

## Image Credentials

Login screen photo *by Amir Esrafili*: <https://unsplash.com/photos/YP0nK_9TuC8>
Desktop photo *by Bjorn Snelders*: <https://unsplash.com/photos/zNNPSqKRR2c>

*Both photos are photoshopped by myself.*

## Followed Guides

- <https://wiki.archlinux.org/title/Installation_guide>

- <https://wiki.archlinux.org/title/EFI_system_partition#Create_the_partition>

- <https://wiki.archlinux.org/title/EFI_system_partition#Typical_mount_points> (Option three)

- <https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS>
