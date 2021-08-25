# Arch-setup

A single file and fully customizable installer script for archlinux.

Archlinux is a distro that it gives full control to anyone who wants to install this distro. With their comprehensive [wiki page](https://wiki.archlinux.org/), one can find satisfying answers to his/her questions and can follow various guides to achieve his/her customized installation. By writing this script, I wanted to retain this customizability while on the other hand automating my installation process.

## Features

*It provides a complete system installation which can be boiled down to:*

- Auto partitioning

- Auto encrypting with cryptsetup ([LVM on LUKS](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS))

- Installing a [set of packages](#Link_to_packages) (both aur and official)

- Installing an aur helper

- Installing a bootloader

- Installing a login manager & greeter

- Adding a user account

Also sets a default background for the desktop and login manager.

## Usage

## How to alter the code?

Visit the [how it works guide](#Link_to_how_it_works) and the rest is up to you.

## Why a bash script?

A large proportion of the linux users are already familiar with bash. Thus, making a modification is straightforward.

## Followed Guides

- <https://wiki.archlinux.org/title/Installation_guide>

- <https://wiki.archlinux.org/title/EFI_system_partition#Create_the_partition>

- <https://wiki.archlinux.org/title/EFI_system_partition#Mount_the_partition> (Option three)

- <https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS>
