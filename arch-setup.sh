#!/bin/bash

# -------------------------------- COPYRIGHT ------------------------------- #
#    <Arch Linux installer>
#    
#    Copyright (C) <2021> <Fatih Yeğin>
#    
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#    
#    E-mail: mail.fyegin@gmail.com
# -------------------------------------------------------------------------- #

#Important note:
#This script is consists of two phases.
#First phase includes: Partitioning - Installing system, bootloader & official packages - Adding a user account & Setting root a password
#Second phase includes: Installing aur packages - Enabling services
#You can find second phase function in the ...th line

#Table of Contents
#



# ---------------------------------- Globals --------------------------------- #

declare DISK_CHECK=""
declare PART_CHECK=""
declare PKG_SELECT=""
declare ANSWER=""

declare PARTITION_TABLE=""
declare TIMEZONE=""
declare DEVICE=""
declare VOLGROUP=""
declare DISK=""
declare IS_UEFI=""
declare IS_ENCRYPT=""
declare IS_SEPERATE=""
declare ESP=""
declare BOOT_PARTITION=""
declare ENCRYPT_PARTITION=""
declare SYSTEM_PARTITION=""
declare HOME_PARTITION=""
declare SWAP_PARTITION=""


#TODO: Paketler açıklanacak
#All additional packages will be prompted to user.
#They will be added to the original set if accepted.
declare CORE_PACKAGES="base linux linux-firmware"

declare ESSENTIAL_PACKAGES="lvm2 sudo base-devel screen git python python-pip cpupower thermald dhcpcd dhclient flatpak parted htop lshw man-db man-pages texinfo mc nano net-tools network-manager-applet networkmanager nm-connection-editor ntfs-3g pacman-contrib unrar unzip p7zip usbutils wget xdg-user-dirs firefox deluge deluge-gtk foliate gimp inkscape keepassxc libreoffice-fresh vlc"

declare ADDITIONAL_PACKAGES="virtualbox jre-openjdk vnstat xsane cups clamav moreutils gparted"

declare BOOTLOADER_PACKAGES="grub intel-ucode amd-ucode"

declare DISPLAY_MANAGER="lightdm"
declare DISPLAY_MANAGER_AUR="lightdm-settings lightdm-slick-greeter"

declare DE_PACKAGES="xorg xorg-server xfce4 xfce4-goodies"
declare DE_DEPENDENT_PACKAGES="eom evolution evolution-on file-roller atril gvfs gvfs-mtp gufw pavucontrol pulseaudio seahorse"

declare AUR_PACKAGES="cpupower-gui-git nano-syntax-highlighting"
declare ADDITIONAL_AUR_PACKAGES="ttf-ms-fonts"

declare VIDEO_DRIVERS="xf86-video-intel xf86-video-nouveau xf86-video-ati xf86-video-amdgpu nvidia nvidia-390xx"
declare SELECTED_VIDEO_DRIVER=""

#Warning: This variable is also modified from the pkg_select function!
declare SERVICES="dhcpcd NetworkManager thermald cpupower lightdm"


# ---------------------------------------------------------------------------- #
#                        Colours for colourful prompting                       #
# ---------------------------------------------------------------------------- #

#declare BLACK='\033[0;30m'
#declare DARK_GRAY='\033[1;30m'
#declare RED='\033[0;31m'
declare LIGHT_RED='\033[1;31m'
#declare GREEN='\033[0;32m'
#declare LIGHT_GREEN='\033[1;32m'
declare ORANGE='\033[0;33m'
declare YELLOW='\033[1;33m'
#declare BLUE='\033[0;34m'
#declare LIGHT_BLUE='\033[1;34m'
declare PURPLE='\033[0;35m'
#declare LIGHT_PURPLE='\033[1;35m'
#declare CYAN='\033[0;36m'
declare LIGHT_CYAN='\033[1;36m'
#declare LIGHT_GRAY='\033[0;37m'
#declare WHITE='\033[1;37m'
declare NOCOLOUR='\033[0m'


# --------------------------------- Functions -------------------------------- #
function check_connection () {

    { ping wiki.archlinux.org -c 1 &>> /dev/null; } || failure "No internet connection!"
}


function prompt_warning () {

    printf "${LIGHT_RED}%s${NOCOLOUR}\n" "$1"
}


function prompt_info () {

    printf "${YELLOW}%s${NOCOLOUR}\n" "$1"
}


function prompt_question () {

    printf "${LIGHT_CYAN}%s${NOCOLOUR}" "$1"
}


function prompt_different () {

    printf "${ORANGE}%s${NOCOLOUR}" "$1"
}


function unmount () {

    #Umount the selected disk
    for i in $(lsblk -o mountpoints "$DISK" | grep / | sort --reverse); do
    
        umount "$i"
    done
    
    #Swapoff if the selected disk has a swap partition
    declare SWAP_U=""
    SWAP_U=$(lsblk -o fstype,path "$DISK" | grep -i swap)
    
    #Check if SWAP_U is non-zero
    if [ -n "$SWAP_U" ]; then
        
        for i in $(echo $SWAP_U | awk '{print $2}'); do
        
            swapoff "$i"
        done
    fi
    
    #Find if it has logical volumes
    declare LVM_U=""
    LVM_U=$(lsblk -o type,path "$DISK" | grep lvm)
    
    #Check if LVM_U is non-zero
    if [ -n "$LVM_U" ]; then
    
        for i in $(echo "$LVM_U" | awk '{print $2}'); do
        
            cryptsetup close "$i"
        done
    fi
    
    #Find if it has LUKS partitions
    declare LUKS_U=""
    LUKS_U=$(lsblk -o type,path "$DISK" | grep crypt)
    
    #Check if LUKS_U is non-zero
    if [ -n "$LUKS_U" ]; then
    
        for i in $(echo "$LUKS_U" | awk '{print $2}'); do
        
            cryptsetup close "$i"
        done
    fi
    
    #And finally inform the kernel
    partprobe
}


function Exit_ () {

    unmount

    exit $1
}


function failure () {

    prompt_warning "$1"
    prompt_warning "Exiting..."
    Exit_ 1
}


function yes_no () {

    read -e -r ANSWER

        while ! output=$([ "$ANSWER" == "y" ] || [ "$ANSWER" == "Y" ] || [ "$ANSWER" == "n" ] || [ "$ANSWER" == "N" ]); do

        prompt_warning "Wrong answer!"
        printf "Please try again: "
        read -e -r ANSWER
    done

    if [ "$ANSWER" == "Y" ]; then ANSWER="y"; fi
    if [ "$ANSWER" == "N" ]; then ANSWER="n"; fi
}


function disk_check () {

    declare INPUT=""
    read -e -r INPUT

    while ! output=$(lsblk -o +path,partlabel | awk '{print $6,$7}' | grep -x "disk $INPUT"); do
    
        prompt_warning "The disk '$INPUT' couldn't found."
        printf "Please try again: "
        read -e -r INPUT
    done

   DISK_CHECK="$INPUT"
}


function partition_check () {

    declare INPUT=""
    read -e -r INPUT

    while ! output=$(lsblk "$DISK" -o +path,partlabel | awk '{print $7}' | grep -x "$INPUT"); do
    
        prompt_warning "Partition '$INPUT' couldn't found."
        printf "Please try again: "
        read -e -r INPUT
    done

   PART_CHECK="$INPUT"
}


function print_packages () {

    #TODO: Print package fonksiyonu düzenlenecek
    
    clear
    prompt_warning "Current selected packages are:"
    printf "${PURPLE}Core Packages: ${NOCOLOUR}"
    prompt_info "$CORE_PACKAGES"
    echo
    
    printf "${PURPLE}Additional Packages: ${NOCOLOUR}"
    prompt_info "$ADDITIONAL_PACKAGES"
    echo
    
    printf "${PURPLE}AUR Packages: ${NOCOLOUR}"
    prompt_info "$AUR_PACKAGES"
    echo
    
    printf "${PURPLE}SELECTED VIDEO_DRIVER: ${NOCOLOUR}"
    prompt_info "$SELECTED_VIDEO_DRIVER"
    echo
}


#Takes additional package sets as an argument
#And asks the user to include each of the packages in the original set or not
function pkg_select () {

    declare PACKAGES=""
    print_packages

    for i in $1; do
    
        prompt_different "Do you want to install $i as well? (y/n):"
        read -e -r ANSWER
        while ! output=$([ "$ANSWER" == "y" ] || [ "$ANSWER" == "Y" ] || [ "$ANSWER" == "n" ] || [ "$ANSWER" == "N" ]); do
        
            prompt_warning "Wrong answer!"
            printf "Please try again: "
            read -e -r ANSWER
        done
        
        if [ "$ANSWER" == "Y" ]; then ANSWER="y"; fi
        
        if [ "$ANSWER" == "y" ]; then
        
            PACKAGES+=" $i"
            
            if [ "$i" == "clamav" ]; then
            
                SERVICES+=" clamav-freshclam"
            fi
        fi
    done
    
    PKG_SELECT="$PACKAGES"
}


# ---------------------------------------------------------------------------- #
#                             Second Phase Function                            #
# ---------------------------------------------------------------------------- #

#Generate a file called "setup_second_phase.sh"
#This function will be used at the end.
#Warning: Mix use of double quotes ("") and single quotes ('')
function setup_second_phase () {

#Get user name that taken after the install function and delete that file
declare USER_NAME=""
USER_NAME="$(cat /mnt/$DEVICE/user_name.txt)"
rm "/mnt/$DEVICE/user_name.txt"

#Inform the user (still in first phase)
prompt_info "Generating setup_second_phase.sh..."

#Below is the code of "setup_second_phase.sh"
{

echo "#!/bin/bash


#Colours for colourful output
declare LIGHT_RED='\033[1;31m'
declare YELLOW='\033[1;33m'
declare NOCOLOUR='\033[0m' #No Colour


#Functions
function check_connection () {

    { ping wiki.archlinux.org -c 1 &>> /dev/null; } || failure \"No internet connection!\"
}

function unmount () {

    #Unmount the mounted partitions recursively
    umount -R \"/mnt/$DEVICE\"

    swapoff \"$SWAP_PARTITION\"

    if [ \"$IS_ENCRYPT\" == \"true\" ]; then
    
        cryptsetup close \"$SWAP_PARTITION\"
        cryptsetup close \"$HOME_PARTITION\"
        cryptsetup close \"$SYSTEM_PARTITION\"

        cryptsetup close \"/dev/mapper/cryptlvm\"
    fi
    
    partprobe
}
"

echo 'function Exit_ () {

    #unmount

    exit $1
}

function prompt_warning () {

    printf "${LIGHT_RED}%s${NOCOLOUR}" "$1"
    echo
}
function prompt_info () {

    printf "${YELLOW}%s${NOCOLOUR}" "$1"
    echo
}

function failure () {

    prompt_warning "$1"
    prompt_warning "Exiting..."
    Exit_ 1
}
'

echo "#The aur function (will be called in chroot)
function aur () {

    #Make a github directory and clone yay in user priviliges
    function clone_yay () {

        check_connection
        
        cd \"/home/$USER_NAME\" || failure \"Cannot change directory to /home/$USER_NAME.\"
        mkdir -p Git-Hub || failure \"/home/$USER_NAME/Git-Hub directory couldn't made.\"
        cd Git-Hub || failure \"Cannot change directory to /home/$USER_NAME/Git-Hub.\"

        git clone https://aur.archlinux.org/yay.git || failure \"Cannot clone yay.\"
    }

    #Generating home directories
    prompt_info \"Generating home directories...\"
    xdg-user-dirs-update
    
    #Export this function to call it in the user's shell
    export -f clone_yay
    prompt_info \"Cloning yay...\"
    su \"$USER_NAME\" /bin/bash -c clone_yay

    #Install yay.
    prompt_info \"Installing yay...\"
    cd \"/home/$USER_NAME/Git-Hub/yay\" || failure \"Cannot change directory to /home/$USER_NAME/Git-Hub.\"
    sudo -u \"$USER_NAME\" makepkg -si --noconfirm || failure \"Error Cannot install yay!\"
    
    #Download pkgbuilds
    prompt_info \"Downloading pkgbuilds...\"
    mkdir -p \"/home/$USER_NAME/.cache/yay\" || { prompt_warning \"Cannot make /home/$USER_NAME/.cache/yay directory!\"; prompt_warning \"Instead, downloading to /home/$USER_NAME\"; }
    
    if [ -d \"/home/$USER_NAME/.cache/yay\" ]; then
        
        cd \"/home/$USER_NAME/.cache/yay\" || failure \"Cannot change directory to /home/$USER_NAME/.cache/yay\"
    else
        
        cd \"/home/$USER_NAME/\" || failure \"Cannot change directory to /home/$USER_NAME/\"
    fi
    sudo -u \"$USER_NAME\" yay --getpkgbuild $AUR_PACKAGES || failure \"Cannot download pkgbuilds!\"
"

echo '    #Install aur packages
    prompt_info "Installing aur packages..."
    find -type f -name "PKGBUILD" -exec makepkg -si --noconfirm {} \;
'

echo "    #Arrange greeter
    prompt_info \"Arranging greeter...\"
    sed \"s/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/g\" /etc/lightdm/lightdm.conf > tmp.txt
    sleep 1s
    #Check if tmp.txt's length is zero
    if ! [ -n \"$(cat tmp.txt)\" ]; then
    
        prompt_info \"Backing up /etc/lightdm/lightdm.conf to /etc/lightdm/lightdm.conf.backup...\"
        mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
        mv tmp.txt /etc/lightdm/lightdm.conf
    else
    
        prompt_warning \"Cannot modify /etc/lightdm/lightdm.conf file.\"
        prompt_warning \"You have to modify it manually.\"
        prompt warning \"greeter-session= should be equal to greeter_session=lightdm-slick-greeter (which is under the [Seat:*] section).\"
        prompt_warning \"Press any key to continue...\"
        read -e -r TMP
    fi

    #Enabling services
    prompt_info \"Enabling services...\"
    for i in $SERVICES; do
        
        systemctl enable $i || {prompt_warning \"Cannot enable $i service!\"; echo \"\"; echo \"$i\" >> /disabled_services.txt; prompt_warning \"Service added to /disabled_services.txt, Please enable it manually.\"; }
    done

    #Generate initramfs
    prompt_info \"Generating initramfs...\"
    mkinitcpio -P
    
    #Return home
    cd /home/\"$USER_NAME\"

    prompt_warning \"AUR configuration complete!\"
}
"

echo '#Exporting variables to be able to use in chroot
export LIGHT_RED="$LIGHT_RED"
export YELLOW="$YELLOW"
export NOCOLOUR="$NOCOLOUR"

'

echo "#Export functions to be able to use in chroot
export -f prompt_info
export -f prompt_warning
export -f failure
export -f aur

#Run aur function
arch-chroot /mnt/\"$DEVICE\" /bin/bash -c \"aur\"

prompt_warning \"ARCH SETUP FINISHED!!\"
prompt_warning \"You can safely reboot now.\"

unmount
"

} > setup_second_phase.sh

chmod +x setup_second_phase.sh

}



# ----------------------------------- Main ----------------------------------- #

#Assumes keyboard layout setted

clear
prompt_different "This script is for installing archlinux on an empty (or semi-empty) disk."
prompt_different "You can modify it to your needs, otherwise XFCE will be installed with a custom package set."
prompt_warning "If you encounter a problem or want to stop the command, you can always press Ctrl-C to quit."
prompt_warning "Use Ctrl-Z in dire situations and reboot your system afterwards as it doesn't actually stop the script."

#Check the internet connection before attempting anything
check_connection

#Set system clock
timedatectl set-ntp true

#Arrange timezone
timedatectl list-timezones | column
prompt_question "Please specify your timezone (ex: de-latin1): "
read -e -r TIMEZONE
timedatectl set-timezone "$TIMEZONE"

#Get device name
while true; do

    prompt_question "Please enter device name: "
    read -e -r DEVICE
    prompt_question "Please re-enter: "
    read -e -r CHECK

    if [ "$DEVICE" == "$CHECK" ]; then

        VOLGROUP="$DEVICE"VolGroup
        break
    else

        prompt_warning "Names don't match!"
        prompt_warning "Please re-enter."
        sleep 2s
        clear
    fi
done

#Get Disk
clear
lsblk -o +path,partlabel | head -1
lsblk -o +path,partlabel | grep "disk"
prompt_question "Please enter the path for the disk you want to operate: "
disk_check
DISK="$DISK_CHECK"

#Unmount just in case
unmount

clear

#Check if system is UEFI
if output=$(ls /sys/firmware/efi/efivars); then

    prompt_info "System boot mode detected as UEFI."
    IS_UEFI="true"
else

    prompt_info "System boot mode detected as legacy BIOS."
    IS_UEFI="false"
fi


#Mbr or gpt?
#You can visit the below link for additional information
#https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks#Partition_tables
if [ "$IS_UEFI" == "false" ]; then

    if [ "gpt" == $(parted "$DISK" --script print | grep "Partition Table:" | awk '{print $3}') ]; then
    
        PARTITION_TABLE="gpt"
    elif [ "msdos" == $(parted "$DISK" --script print | grep "Partition Table:" | awk '{print $3}') ]; then
    
        PARTITION_TABLE="msdos"
    else
    
        PARTITION_TABLE="other"
    fi
fi

# ------------------------------- Partitioning ------------------------------- #
#In the below link, you can find the answer for the question of - Why first partition generally starts from sector 2048 (1mib)? -
#https://www.thomas-krenn.com/en/wiki/Partition_Alignment_detailed_explanation

prompt_question "Do you want to use auto partitioning? - All data will be ERASED! - (y/n): "
yes_no
if [ "$ANSWER" == "y" ]; then
    
    #TODO: Yeterli alan var mı diye kontrol edilecek
    #TODO: Alan 2Tib'den fazlaysa gpt yapılacak
    
    #Sizing                                             #Configurations used
    #BIOS Grub - 1mib (If needed)
    #EFI System Partition [ESP] - 512mib (If needed)    https://superuser.com/questions/1310927/what-is-the-absolute-minimum-size-a-uefi-system-partition-can-be/1310938#1310938
    #Boot - 500mib
    #Swap - 8gib                                        https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
    #System - 32gib (If seperate)
    #Home - All of the available space
    
    if output=$([ "$PARTITION_TABLE" != "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        prompt_different "Two of the popular linux supported partition tables are GPT and MBR."
        prompt_different "GUID Partition Table (GPT) is a replacement for legacy Master Boot Record (MBR) partition table."
        prompt_different "It has better features and functionality."
        prompt_different "However, if you plan to install Windows or want it for some specific reason you can still use MBR."
        prompt_different "For additional information visit this link - https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks#Partition_tables -"
        prompt_different "Note: Some elder hardware may have issues when booting from GPT."
        prompt_question "Do you want to use MBR? (y/n): "
        yes_no
        if [ "$ANSWER" == "y" ]; then
        
            PARTITION_TABLE="msdos" #Parted refers msdos as mbr
        else
        
            PARTITION_TABLE="gpt"
        fi
    fi
    
    prompt_question "Do you want an encrypted system partition? (y/n): "
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        IS_ENCRYPT="true"
    else
    
        IS_ENCRYPT="false"
    fi
    
    
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        if [ "$IS_UEFI" == "true" ]; then #Encrypt true, UEFI=true
        
            parted "$DISK" --script "mktable gpt" \
                                    "mkpart EFI System Partition 1mib 513mib" \
                                    "mkpart BOOT 514mib 1014mib" \
                                    "mkpart SYSTEM 1015mib -1"
            
            ESP="$DISK"1
            BOOT_PARTITION="$DISK"2
            ENCRYPT_PARTITION="$DISK"3
        else
        
            if [ "$PARTITION_TABLE" == "gpt" ]; then #Encrypt true, UEFI=false, partition table=gpt
            
                parted "$DISK" --script "mktable gpt" \
                                        "mkpart GRUB 1mib 2mib" \
                                        "mkpart BOOT 3mib 503mib" \
                                        "mkpart SYSTEM 504mib -1"
                                        
                    parted "$DISK" --script "set 1 bios_grub on"
                
                BOOT_PARTITION="$DISK"2
                ENCRYPT_PARTITION="$DISK"3
            else #Encrypt true, UEFI=false, partition table=mbr
            
                parted "$DISK" --script "mktable msdos" \
                                        "mkpart primary 1mib 501mib" \
                                        "mkpart primary 502mib -1"
                
                BOOT_PARTITION="$DISK"1
                ENCRYPT_PARTITION="$DISK"2
            fi
        fi
    else
    
        prompt_question "Do you want seperate home and system partitions? (y/n): "
        yes_no
        if [ "$ANSWER" == "y" ]; then
        
            IS_SEPERATE="true"
        else
        
            IS_SEPERATE="false"
        fi
        
        
        if [ "$IS_UEFI" == "true" ]; then
        
            if [ "$IS_SEPERATE" == "true" ]; then #Encrypt false, UEFI=true, is seperate=true
                
                parted "$DISK" --script "mktable gpt" \
                                        "mkpart EFI System Partition 1mib 513mib" \
                                        "mkpart BOOT 514mib 1014mib" \
                                        "mkpart SWAP 1015mib 8.99gib" \
                                        "mkpart SYSTEM 9gib 41gib" \
                                        "mkpart HOME 41.1gib -1"
                
                ESP="$DISK"1
                BOOT_PARTITION="$DISK"2
                SWAP_PARTITION="$DISK"3
                SYSTEM_PARTITION="$DISK"4
                HOME_PARTITION="$DISK"5
            else #Encrypt false, UEFI=true, is seperate=false
            
                parted "$DISK" --script "mktable gpt" \
                                        "mkpart EFI System Partition 1mib 513mib" \
                                        "mkpart BOOT 514mib 1014mib" \
                                        "mkpart SWAP 1015mib 8.99gib" \
                                        "mkpart SYSTEM 9gib -1"
                    
                ESP="$DISK"1
                BOOT_PARTITION="$DISK"2
                SWAP_PARTITION="$DISK"3
                SYSTEM_PARTITION="$DISK"4
            fi
        else 
        
            if [ "$IS_SEPERATE" == "true" ]; then
                
                if [ "$PARTITION_TABLE" == "gpt" ]; then #Encrypt false, UEFI=false, is seperate=true, partition table=gpt
                
                    parted "$DISK" --script "mktable gpt" \
                                            "mkpart GRUB 1mib 2mib" \
                                            "mkpart BOOT 3mib 503mib" \
                                            "mkpart SWAP 504mib 8.49gib" \
                                            "mkpart SYSTEM 8.50gib 40.50gib" \
                                            "mkpart HOME 40.51gib -1"
                    
                    parted "$DISK" --script "set 1 bios_grub on"
                    
                    BOOT_PARTITION="$DISK"2
                    SWAP_PARTITION="$DISK"3
                    SYSTEM_PARTITION="$DISK"4
                    HOME_PARTITION="$DISK"5
                else #Encrypt false, UEFI=false, is seperate=true, partition table=mbr
                
                    parted "$DISK" --script "mktable msdos" \
                                            "mkpart primary 1mib 501mib" \
                                            "mkpart extended 502mib -1" \
                                            "mkpart logical 503mib 8.49gib" \
                                            "mkpart logical 8.50gib 40.50gib" \
                                            "mkpart logical 40.51gib -1"
                    
                    BOOT_PARTITION="$DISK"1
                    #Warning! Logical partitions start from 5.
                    #The reason is that in MBR partition table only four primary partitions can be made, so the first four is reserved
                    SWAP_PARTITION="$DISK"5
                    SYSTEM_PARTITION="$DISK"6
                    HOME_PARTITION="$DISK"7
                fi
            else
            
                if [ "$PARTITION_TABLE" == "gpt" ]; then #Encrypt false, UEFI=false, is seperate=false, partition table=gpt
                
                    parted "$DISK" --script "mktable gpt" \
                                            "mkpart GRUB 1mib 2mib" \
                                            "mkpart BOOT 3mib 503mib" \
                                            "mkpart SWAP 504mib 8.49gib" \
                                            "mkpart SYSTEM 8.50gib -1"
                                        
                    parted "$DISK" --script "set 1 bios_grub on"
                    
                    BOOT_PARTITION="$DISK"2
                    SWAP_PARTITION="$DISK"3
                    SYSTEM_PARTITION="$DISK"4
                else #Encrypt false, UEFI=false, is seperate=false, partition table=mbr
                
                    parted "$DISK" --script "mktable msdos" \
                                            "mkpart primary 1mib 501mib" \
                                            "mkpart extended 502mib -1" \
                                            "mkpart logical 503mib 8.49gib" \
                                            "mkpart logical 8.50gib -1"
                    
                    BOOT_PARTITION="$DISK"1
                    #Warning! Logical partitions start from 5.
                    #The reason is that in MBR partition table only four primary partitions can be made, so the first four is reserved
                    SWAP_PARTITION="$DISK"5
                    SYSTEM_PARTITION="$DISK"6
                fi
            fi
        fi
    fi
else #Manuel partition selection
    
    #Partition table is not suitable for linux
    [ "$PARTITION_TABLE" == "other" ] && { prompt_warning "ERROR! Partition table not supported! "; failure "Please use auto partitioning or format it with a correct table (MBR or GPT)."; }
    
    #Inform the user about needed partitions
    prompt_different "Needed partitions are:"
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
        prompt_different "#BIOS Grub Partition"
    elif [ "$IS_UEFI" == "true" ]; then
        prompt_different "#EFI System Partition"
    fi
    prompt_different "#Boot Partition"
    prompt_different "#Swap Partition"
    prompt_different "#System Partition"
    prompt_different "#Home Partition"
    
    
    #Get BIOS Grub partition
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        clear
        parted --script "$DISK" "print"
        prompt_question "Please specify the number for the Grub parition (1mib partition advised): "
        read -e -r GRUB_PARTITION_NUMBER
        while ! output=$(parted "$DISK" --script "print" | awk '{print $1}' | grep "$GRUB_PARTITION_NUMBER" &>> /dev/null); do
    
            prompt_warning "Wrong number!"
            printf "Answer: "
            read -e -r GRUB_PARTITION_NUMBER
        done
        
        parted "$DISK" --script "set $GRUB_PARTITION_NUMBER bios_grub on"
        sleep 2s
    fi
    
    #Print the disk
    clear
    lsblk "$DISK" -o +path,partlabel
    
    #Get ESP
    if [ "$IS_UEFI" == "true" ]; then
        
        #Make is_esp directory and don't prompt for error if exist
        mkdir -p /mnt/is_esp
    
        while true; do
        
            prompt_question "Please enter the path for EFI System partiton: "
            partition_check
            mount "$PART_CHECK" /mnt/is_esp
            
            #Look for EFI directory. If it exists then it is an ESP.
            if [ -d "/mnt/is_esp/EFI" ]; then
            
                ESP="$PART_CHECK"
                umount /mnt/is_esp
                break
            else
            
                umount /mnt/is_esp
                prompt_warning "Not an EFI System partition!"
                prompt_warning "Please re-enter!"
                sleep 2s
                clear
            fi
        done
    fi
    
    #Get Boot
    prompt_question "Please enter the path for a Boot partition: "
    partition_check
    BOOT_PARTITION="$PART_CHECK"
    
    #Get Swap
    prompt_question "Please enter the path for a Swap partition: "
    partition_check
    SWAP_PARTITION="$PART_CHECK"

    #Is seperate?
    prompt_different "Does home and system partitions seperate? (y/n)"
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        IS_SEPERATE="true"
    
        #Get System or LUKS
        prompt_question "Please enter the path for a System or LUKS partition:"
        partition_check
        
        #Check if it's a LUKS partition
        if output=$(lsblk -o +path,fstype | awk '{print $7,$8}' | grep -x "$PART_CHECK crypto_LUKS"); then
    
            prompt_info "Opening system partition..."
            cryptsetup open "$PART_CHECK" cryptlvm
            sleep 2s
            clear
            lsblk "$DISK" -o +path,partlabel
    
            prompt_question "Please enter the path for a System partition:"
            partition_check
            SYSTEM_PARTITION="$PART_CHECK"
        else
        
            SYSTEM_PARTITION="$PART_CHECK"
        fi
    
        #Home
        prompt_question "Please enter the path for a Home partition:"
        partition_check
        HOME_PARTITION="$PART_CHECK"
    else

        IS_SEPERATE="false"
    
        #Get Systen or LUKS
        prompt_question "Please enter the path for a System or LUKS partition:"
        partition_check
        
        #Check if it's a LUKS partition
        if output=$(lsblk -o +path,fstype | awk '{print $7,$8}' | grep -x "$PART_CHECK crypto_LUKS"); then
    
            prompt_info "Opening system partition..."
            cryptsetup open "$PART_CHECK" cryptlvm
            sleep 2s
            clear
            lsblk "$DISK" -o +path,partlabel
    
            prompt_question "Please enter the path for a Root partition:"
            partition_check
            SYSTEM_PARTITION="$PART_CHECK"
        else
        
            SYSTEM_PARTITION="$PART_CHECK"
        fi
    fi
fi

# -------------------------------- Encrypting -------------------------------- #
if [ "$IS_ENCRYPT" == "true" ]; then

    #TODO: Encrypt yapılacak
fi

#Mounting efi
#https://wiki.archlinux.org/title/EFI_system_partition#Mount_the_partition
