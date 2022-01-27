# Arch-setup

***[This Repository is now on Slow maintenance mode; don't expect new functionality.]***

A single and fully customizable installer script for archlinux.

Archlinux is a distro that it gives full control to anyone who wants to install this distro. With their comprehensive [wiki page](https://wiki.archlinux.org/), one can find satisfying answers to his/her questions and can follow various guides to achieve his/her customized installation. By writing this script, I wanted to retain this customizability while on the other hand automating my installation process.

And you can do so too. It is a single bash script after all. Just follow [how to modify the code](#how-to-modify-the-code) section.

## Features

*`arch-setup.sh` provides a complete system installation which can be boiled down to:*

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

To see the package list, please read: [Packages.md](https://github.com/The-Plottwist/Arch-setup/blob/main/Packages.md)

## US Layout

This is the default layout when archiso boots.

![alt text](assets/other/640px-KB_United_States-NoAltGr.svg.png)

*Source: <https://commons.wikimedia.org/wiki/File:KB_United_States.svg>*

## Usage

After [booting into the live environment](https://wiki.archlinux.org/title/Installation_guide#Boot_the_live_environment), do:

**Enable Internet Connection:**

- If you have a wired connection, just type `dhcpcd` and test it with `ping archlinux.org -c 1`

- Otherwise follow this guide: <https://www.linuxandubuntu.com/home/how-to-setup-a-wifi-in-arch-linux-using-terminal>

**Clone the Repository:**

- Install git: `pacman -S git`

- Clone the repo: `git clone https://github.com/The-Plottwist/Arch-setup`

- Change your directory to cloned repo: `cd Arch-setup` (This is necessary for background images)

- Run the script: `./arch-setup.sh`

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

You can read: [Breaking-into-pieces.md](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md) and [Before-altering.md](https://github.com/The-Plottwist/Arch-setup/blob/main/Before-altering.md)

Rest is up to you.

***Sidenote: The source code version used in the [Breaking-into-pieces.md](https://github.com/The-Plottwist/Arch-setup/blob/main/Breaking-into-pieces.md) is different form the development branch. It is only there for learning purposes and will not run due to alterations made to make it look pretty.***

## Image Credentials

Login screen photo *by Amir Esrafili*: <https://unsplash.com/photos/YP0nK_9TuC8>

Desktop photo *by Bjorn Snelders*: <https://unsplash.com/photos/zNNPSqKRR2c>

*Both photos are photoshopped by myself.*

## Followed Guides

- <https://wiki.archlinux.org/title/Installation_guide>

- <https://wiki.archlinux.org/title/EFI_system_partition#Create_the_partition>

- <https://wiki.archlinux.org/title/EFI_system_partition#Typical_mount_points> (Option three)

- <https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/installation_guide/s2-diskpartrecommend-x86> (For swap space allocation)

- <https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS>
