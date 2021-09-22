# Partitioning Manual

---

***Beware! You can lose your data, proceed at your own risk!***

---

Below is the table of available partitioning tools for linux:

| Dialog | Pseudo-graphics | Graphical          | Non-interactive |
| ------ | --------------- | ------------------ | --------------- |
| fdisk  | cfdisk          | Gparted            | sfdisk          |
| gdisk  | cgdisk          | gnome-disk-utility | sgdisk          |
| parted | ---             | partitionmanager   | parted          |

This is a manual about how I get things done. So, I will be explaining `lsblk` and `parted`. For other tools you see on the upper table, please follow one of the various manuals on the internet. You can also be able to apply these descriptions after booting into archiso.

- [Partitioning Manual](#partitioning-manual)
  - [1. Lsblk output](#1-lsblk-output)
  - [2. Choose your disk](#2-choose-your-disk)
  - [3. Verify your boot mode](#3-verify-your-boot-mode)
  - [4. Partitioning](#4-partitioning)
    - [(Theory)](#theory)
      - [A. Partition tables](#a-partition-tables)
      - [B. Partition Types](#b-partition-types)
        - [GPT](#gpt)
        - [MBR](#mbr)
      - [C. Needed Partitions](#c-needed-partitions)
      - [D. Partition Sizes](#d-partition-sizes)
    - [(Practice)](#practice)
      - [A. GPT](#a-gpt)
        - [Set Your Starting Sector](#set-your-starting-sector)
        - [Unit of Measurement](#unit-of-measurement)
        - [Partition table (Optional)](#partition-table-optional)
        - [Partitions](#partitions)
          - [EFI System Partition](#efi-system-partition)
      - [B. MBR](#b-mbr)

## 1. Lsblk output

You can list your devices with `lsblk -o +path`.

Such as:

![lsblk](assets/manuals/partitioning/lsblk.png)

As you can see, all of the information is divided into certain columns. Important ones for us however are `NAME`, `SIZE`, `TYPE`, `MOUNTPOINTS` and `PATH`.

- `NAME`: Shows devices in a tree form. The head of the tree is your disk and below are its partitions.

- `SIZE`: Device size

- `TYPE`: Device type

  - `disk`: Data storage device
  - `part`: Partition
  - `crypt`: Encrypted device
  - `lvm`: Logical Volume
  - `rom`: Comes from `DVD/CD-ROM` means it is an optical device.

- `MOUNTPOINTS`: Shows where device is mounted on the system. (however, this indicator `[SWAP]` means swapping is enabled.)

- `PATH`: Path to access your device.

*(For other columns you see in the picture, please visit: <https://superuser.com/questions/778686/linux-lsblk-output>)*

Yet all of them are not limited to the ones that described above. To see what columns `lsblk` has, type `lsblk --help` in your terminal. You can then use them with `lsblk -o +column1,column2...` *(I mostly use `lsblk -o +partlabel`)*

## 2. Choose your disk

In general, you should be familiar with above description and decide your target device according to it.

On the other hand, since we will be partitioning, we only need to know which `disk`'s are seen by our system.

Therefore, typing `lsblk -o +path | grep disk` will suffice. Then you can differ them by their sizes.

![lsblk+grep](assets/manuals/partitioning/lsblk-grep.png)

- `/dev/sda`: My main device (SSD).

- `/dev/sdb`: My target device (An old hard drive).

- `/dev/sdc`: My USB.

## 3. Verify your boot mode

There are two boot modes:

- `UEFI` (Unified Extensible Firmware Interface)

- `Legacy BIOS` (Basic Input Output System)

To know which mode you are in, type: `ls /sys/firmware/efi/efivars`.

If you successfully list the contents of that file, then you are in `UEFI` mode.

If you encounter with this:

![efivars](assets/manuals/partitioning/efivars.png)

then you are in `Legacy BIOS` mode.

## 4. Partitioning

### (Theory)

Partitioning is a scheming process that allows the use of a data storage device.

#### A. Partition tables

There are two suitable partition tables for linux. `MBR` and `GPT`.

`MBR` (a.k.a `msdos`) is the old fashioned way of handling partitions.

`GPT` on the other hand is newer and offers more flexibility.

*(For more information about partition tables, visit: <https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks#Partition_tables>)*

**Have to use `GPT` if:**

- your boot mode is `UEFI`
- your data storage device is bigger than `2TB`

**Have to use `MBR` if:**

- your boot mode is `Legacy BIOS` and want to dual boot with windows
- your boot mode is `Legacy BIOS` and experienced problems with `GPT`
- you want better compatibility with your elder hardware

#### B. Partition Types

Each partition table has its own way of handling partitions.

##### GPT

All partitions differ each other from their numbers and allocated regions. There are no exclusive types.

##### MBR

- `primary`: There could only be four `primary` partitions due to small space used at the beginning of the disk (usually 512 bytes).

- `extended`: To overcome `primary`'s restriction, this type is used. Thus, it allows a room for storing more partitions. (i.e. partitions in a partition)

- `logical`: The type that is used inside the `extended` partition.

#### C. Needed Partitions

`GPT` `Legacy BIOS`:

- `BIOS GRUB`
- `BOOT`
- `SWAP`
- `SYSTEM`
- `HOME` (if you want it seperated)

`GPT` `UEFI`:

- `EFI System Partition`
- `BOOT`
- `SWAP`
- `SYSTEM`
- `HOME` (if you want it seperated)

`MBR`:

- `BOOT`
- `SWAP`
- `SYSTEM`
- `HOME` (if you want it seperated)

#### D. Partition Sizes

- `BIOS GRUB`: **Must be** `1MiB`
- `EFI System Partition`: `512MiB` recommended
- `BOOT`: `500MiB` recommended
- `SWAP`:
  - General rule: Twice the size of `RAM`
  - However, you can use [Ubuntu guidelines](https://help.ubuntu.com/community/SwapFaq#How_much_swap_do_I_need.3F) too.
- `SYSTEM`:
  - if seperate: `32GiB` recommended
  - else: Rest of the disk
- `HOME`: Rest of the disk

### (Practice)

Enough of theory. Let's see some action!

To enter `parted`'s dialog mode, type: `parted YOUR_TARGET_DEVICE`

![parted-welcome](assets/manuals/partitioning/parted-welcome.png)

and to see your current configuration, type `print`:

![parted-print](assets/manuals/partitioning/parted-print.png)

*Note: You can shorten these commands (e.g `print` to `p` or `mktable` to `mkt`)*

#### A. GPT

##### Set Your Starting Sector

<!-- TODO: (Parted-align) https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/ -->

##### Unit of Measurement

type `unit mib` to change your unit of measurement to `MiB`.

##### Partition table (Optional)

type `mktable gpt`:

![parted-gpt](assets/manuals/partitioning/parted-gpt.png)

It's now looking like this:

![parted-gpt-print1](assets/manuals/partitioning/parted-gpt-print1.png)

##### Partitions

General syntax is `mkpart PARTITION_NAME START END`.

###### EFI System Partition

type `mkpart "EFI System Partition" 1mib 513mib`:

![parted-gpt-efi](assets/manuals/partitioning/parted-gpt-efi.png)

#### B. MBR
