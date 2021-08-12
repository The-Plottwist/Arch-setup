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
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#    GNU General Public License for more details.
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#    
#    E-mail: mail.fyegin@gmail.com
# -------------------------------------------------------------------------- #

#Important note:
#This script is consists of two phases.
#First phase includes: Partitioning - Installing system - Installing bootloader & official packages - Adding user account & Setting a root password
#Second phase includes: Installing aur helper & aur packages - Enabling services
#You can find second phase function in the ...th line

#Table of Contents
#


#Followed guide:
#https://wiki.archlinux.org/title/Installation_guide


# ---------------------------------- Globals --------------------------------- #

declare DISK_CHECK=""
declare PART_CHECK=""
declare NUMBER_CHECK=""
declare PKG_SELECT=""
declare ANSWER=""
declare SELECTION=""

declare PARTITION_TABLE=""
declare DEVICE=""
declare VOLGROUP=""
declare DISK=""
declare DISK_SIZE_TIB=""
declare DISK_SIZE_MIB=""
declare IS_UEFI=""
declare IS_ENCRYPT=""
declare IS_SEPERATE=""
declare ESP=""
declare IS_ESP_FORMAT=""
declare BOOT_PARTITION=""
declare ENCRYPT_PARTITION=""
declare SYSTEM_PARTITION=""
declare HOME_PARTITION=""
declare SWAP_PARTITION=""


#TODO: Paketler açıklanacak
#All additional packages will be asked to the user.
#They will be added to the original set if accepted.
declare CORE_PACKAGES="base linux linux-firmware"

declare PACKAGES="lvm2 sudo base-devel screen git python python-pip cpupower thermald dhcpcd dhclient flatpak parted htop lshw man-db man-pages texinfo mc nano net-tools network-manager-applet networkmanager nm-connection-editor ntfs-3g pacman-contrib unrar unzip p7zip usbutils wget xdg-user-dirs firefox deluge deluge-gtk foliate gimp inkscape keepassxc libreoffice-fresh vlc"

declare ADDITIONAL_PACKAGES="virtualbox jre-openjdk vnstat xsane cups clamav moreutils gparted"

declare BOOTLOADER_PACKAGES="grub intel-ucode amd-ucode"

declare DE_PACKAGES="xorg xorg-server xfce4 xfce4-goodies"
declare DE_DEPENDENT_PACKAGES="eom evolution evolution-on file-roller atril gvfs gvfs-mtp gufw pavucontrol pulseaudio seahorse"

declare AUR_PACKAGES="lightdm-settings cpupower-gui-git nano-syntax-highlighting"
declare ADDITIONAL_AUR_PACKAGES="ttf-ms-fonts"

declare DISPLAY_MANAGER="lightdm"

declare GREETER=""
declare GREETER_AUR="lightdm-slick-greeter"
declare SELECTED_GREETER=""

declare VIDEO_DRIVER="xf86-video-intel xf86-video-nouveau xf86-video-ati xf86-video-amdgpu nvidia"
declare VIDEO_DRIVER_AUR="nvidia-390xx"
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
declare LIGHT_GREEN='\033[1;32m'
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

    printf "${YELLOW}\n%s\n${NOCOLOUR}\n" "$1"
}


function prompt_question () {

    printf "${LIGHT_CYAN}%s${NOCOLOUR}" "$1"
}


function prompt_different () {

    printf "${LIGHT_GREEN}%s${NOCOLOUR}" "$1"
}

function prompt_path () {

    printf "${LIGHT_CYAN}Please enter the${LIGHT_RED} PATH ${LIGHT_CYAN}for %s${NOCOLOUR}" "$1"
}


function unmount () {

    #Umount the selected disk
    
    prompt_info "Unmounting please wait..."
    
    for i in $(lsblk -o mountpoints "$DISK" | grep / | sort --reverse); do
    
        umount "$i"
    done

    sleep 2s

    #Swapoff if the selected disk has a swap partition
    declare SWAP_U=""
    SWAP_U=$(lsblk -o fstype,path "$DISK" | grep -i swap)
    
    #Check if SWAP_U is non-zero
    if [ -n "$SWAP_U" ]; then
        
        for i in $(echo $SWAP_U | awk '{print $2}'); do
        
            swapoff "$i"
        done
    fi

    sleep 2s

    #Find if it has logical volumes
    declare LVM_U=""
    LVM_U=$(lsblk -o type,path "$DISK" | grep lvm)
    
    #Check if LVM_U is non-zero
    if [ -n "$LVM_U" ]; then
    
        for i in $(echo "$LVM_U" | awk '{print $2}'); do
        
            cryptsetup close "$i"
        done
    fi

    sleep 2s

    #Find if it has LUKS partitions
    declare LUKS_U=""
    LUKS_U=$(lsblk -o type,path "$DISK" | grep crypt)
    
    #Check if LUKS_U is non-zero
    if [ -n "$LUKS_U" ]; then
    
        for i in $(echo "$LUKS_U" | awk '{print $2}'); do
        
            cryptsetup close "$i"
        done
    fi

    sleep 2s

    #And finally inform the kernel
    partprobe &>> /dev/null
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

        echo
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


function number_check () {

    declare max_=0
    max_=$1
    
    read -e -r NUMBER_CHECK
    while output=$( [[ ! $NUMBER_CHECK =~ ^[0-9]+$ ]] || (( NUMBER_CHECK > max_ )) ); do
    
        prompt_warning "Wrong number!"
        printf "${LIGHT_CYAN}Please re-enter: ${NOCOLOUR}"
        read -e -r NUMBER_CHECK
    done
}


function print_packages () {

    #TODO: Paketlere link verilecek

    clear
    
    prompt_warning "Current selected packages are:"
    
    printf "${PURPLE}Core Packages: ${NOCOLOUR}"
    prompt_info "$CORE_PACKAGES"
    echo
    
    printf "${PURPLE}Packages: ${NOCOLOUR}"
    prompt_info "$PACKAGES"
    echo
    
    printf "${PURPLE}Bootloader Packages: ${NOCOLOUR}"
    prompt_info "$BOOTLOADER_PACKAGES"
    echo
    
    printf "${PURPLE}Display Manager: ${NOCOLOUR}"
    prompt_info "$DISPLAY_MANAGER"
    echo
    
    printf "${PURPLE}Desktop Environment Packages: ${NOCOLOUR}"
    prompt_info "$DE_PACKAGES"
    echo
    
    printf "${PURPLE}Desktop Environment Dependent Packages: ${NOCOLOUR}"
    prompt_info "$DE_DEPENDENT_PACKAGES"
    echo
    
    printf "${PURPLE}Aur Packages: ${NOCOLOUR}"
    prompt_info "$AUR_PACKAGES"
    echo
    
    prompt_warning "Greeter: $SELECTED_GREETER"
    echo
    
    prompt_warning "Video Driver: $SELECTED_VIDEO_DRIVER"
    echo
}


function pkg_select () {
#Takes additional package sets as an argument
#And asks the user to include each of the packages in the original set or not

    declare SELECTION_=""
    print_packages

    for i in $1; do
    
        printf "${LIGHT_GREEN}Do you want to install ${LIGHT_RED}%s ${LIGHT_GREEN}as well? (y/n)${LIGHT_GREEN}: ${NOCOLOUR}" "$i"
        yes_no
        
        #Delete the previous line
        printf "\033[1A\033[2K\r"
        
        if [ "$ANSWER" == "y" ]; then
        
            SELECTION_+=" $i"
            
            if [ "$i" == "clamav" ]; then
            
                SERVICES+=" clamav-freshclam"
            fi
        fi
    done
    
    PKG_SELECT="$SELECTION_"
}


function choose_one () {

    declare MESSAGE=""
    declare OFFICIAL_PKGS=""
    declare AUR_PKGS=""
    
    MESSAGE="$1"
    OFFICIAL_PKGS="$2"
    AUR_PKGS="$3"

    #Print packages
    prompt_different "$MESSAGE"
    echo
    echo
    
    declare -i max=0
    for i in $OFFICIAL_PKGS; do
    
        max+=1
        printf "${PURPLE}%s (${LIGHT_CYAN}%s${PURPLE}) ${NOCOLOUR}" "$i" "$max"
    done
    
    declare -i aur_part=0
    aur_part+=$max+1
    for i in $AUR_PKGS; do
    
        max+=1
        printf "${PURPLE}%s (${LIGHT_CYAN}%s${PURPLE}) ${NOCOLOUR}" "$i" "$max"
    done
    echo
    
    #Selection
    printf "Please choose one: "
    number_check "$max"
    
    #Include it in the installation
    declare -i current=0
    for i in $OFFICIAL_PKGS $AUR_PKGS; do
    
        current+=1
        if [ "$current" == "$NUMBER_CHECK" ]; then
        
            if (( current < aur_part )); then
            
                PACKAGES=" $i"
                break
            elif (( current >= aur_part )); then
            
                AUR_PACKAGES+=" $i"
                break
            fi
            
            SELECTION="$i"
        fi
    done
}

# ---------------------------------------------------------------------------- #
#                    Second Phase (Will be used at the end)                    #
# ---------------------------------------------------------------------------- #

#Generate a file called "setup_second_phase.sh"
#Warning: Mix use of double quotes ("") and single quotes ('')
function setup_second_phase () {

#Get user name that taken after first phase and delete that file
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


# ---------------------------------------------------------------------------- #
#                                   Functions                                  #
# ---------------------------------------------------------------------------- #


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

    #Make a github directory and clone yay (will be called in user's terminal)
    function clone_yay () {

        #Generating home directories
        prompt_info \"Generating home directories...\"
        xdg-user-dirs-update

        check_connection

        cd \"/home/$USER_NAME\" || failure \"Cannot change directory to /home/$USER_NAME.\"
        mkdir -p Git-Hub || failure \"/home/$USER_NAME/Git-Hub directory couldn't made.\"
        cd Git-Hub || failure \"Cannot change directory to /home/$USER_NAME/Git-Hub.\"

        git clone https://aur.archlinux.org/yay.git || failure \"Cannot clone yay.\"
    }

    #Generating home directories
    prompt_info \"Generating home directories...\"
    xdg-user-dirs-update
    
    #Install go for yay
    prompt_info \"Installing go for aur helper... -yay-\"
    pacman -S --noconfirm go
    
    #Export clone_yay function to call it in the user's shell
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

echo "    #Check if /etc/lightdm directory exists
    if [ -d \"/etc/lightdm\" ]; then
    
        prompt_info \"Enabling $SELECTED_GREETER...\"
        declare LIGHTDM_CONF=\"\"
        LIGHTDM_CONF=\$(sed \"s/#greeter-session=example-gtk-gnome/greeter-session=$SELECTED_GREETER/g\" /etc/lightdm/lightdm.conf)
        sleep 1s
        if [ -n \"\$LIGHTDM_CONF\" ]; then
        
            prompt_info \"Backing up /etc/lightdm/lightdm.conf to /etc/lightdm/lightdm.conf.backup...\"
            mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
            echo \"\$LIGHTDM_CONF\" > /etc/lightdm/lightdm.conf
        else
        
            prompt_warning \"Cannot modify /etc/lightdm/lightdm.conf file.\"
            prompt_warning \"You have to modify it manually.\"
            prompt warning \"greeter-session=example-gtk-gnome should be equal to greeter_session=$SELECTED_GREETER (which is under the [Seat:*] section).\"
            prompt_warning \"Press any key to continue...\"
            read -e -r TMP
        fi
    fi

    #Enabling services
    prompt_info \"Enabling services...\"
    for i in $SERVICES; do
        
        systemctl enable \$i || {prompt_warning \"Cannot enable \$i service!\"; echo \"\"; echo \"\$i\" >> /disabled_services.txt; prompt_warning \"Service added to /disabled_services.txt, Please enable it manually.\"; }
    done

    #Generate initramfs
    prompt_info \"Generating initramfs...\"
    mkinitcpio -P
    
    #Return home
    cd \"/home/$USER_NAME\"

    prompt_warning \"AUR configuration complete!\"
}
"

echo '
# ---------------------------------------------------------------------------- #
#                              Script starts here                              #
# ---------------------------------------------------------------------------- #

'

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
arch-chroot \"/mnt/$DEVICE\" /bin/bash -c \"aur\"

prompt_warning \"ARCH SETUP FINISHED!!\"
prompt_warning \"You can safely reboot now.\"

unmount
"

} > setup_second_phase.sh

chmod +x setup_second_phase.sh

}



# ---------------------------------------------------------------------------- #
#                                  First Phase                                 #
# ---------------------------------------------------------------------------- #

#Assuming keyboard layout has already been set

#Disclaimer
clear
prompt_different "This script is for installing archlinux on an empty (or semi-empty) disk."
echo

prompt_different "You can modify it to your needs, otherwise XFCE will be installed with a custom package set."
echo
echo

printf "${ORANGE}If you encounter a problem or want to stop the command, you can always press Ctrl-C to quit.${NOCOLOUR}\n"
printf "${ORANGE}Use Ctrl-Z in dire situations and reboot your system afterwards as it doesn't actually stop the script.${NOCOLOUR}\n"
echo

prompt_warning "This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License V3 for more details."
echo

#Check the internet connection before attempting anything
check_connection

#Set time synchronization active
timedatectl set-ntp true

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
        echo
    fi
done

#Get Disk
clear
lsblk -o +path,partlabel | head -1
lsblk -o +path,partlabel | grep "disk"
prompt_path "the disk you want to operate: "
disk_check
DISK="$DISK_CHECK"

unmount

#Check if system is UEFI
if [ -d /sys/firmware/efi/efivars ]; then

    prompt_info "System boot mode detected as UEFI."
    IS_UEFI="true"
else

    prompt_info "System boot mode detected as legacy BIOS."
    IS_UEFI="false"
fi


# ------------------------------ Partition Table ----------------------------- #
#You can visit the below link for additional information
#https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks#Partition_tables

#Get disk size in MiB and subtract the extension
DISK_SIZE_MIB=$(parted "$DISK" --script "u mib" \ "print" | grep "Disk $DISK:" | awk '{print $3}' | sed s/[A-Za-z]//g)
#Convert it to TiB
DISK_SIZE_TIB=$(( DISK_SIZE_MIB/(1024*1024) ))

#Wait before using parted again in case the disk is old
sleep 2s

#Get Partition Table
PARTITION_TABLE=$(parted "$DISK" --script print | grep "Partition Table:" | awk '{print $3}')

if output=$([ "$PARTITION_TABLE" != "msdos" ] && [ "$PARTITION_TABLE" != "gpt" ]); then

    PARTITION_TABLE="other"
fi


# ------------------------------- Partitioning ------------------------------- #
#In the below link, you can find the answer for the question of - Why first partition generally starts from sector 2048 (1mib)? -
#https://www.thomas-krenn.com/en/wiki/Partition_Alignment_detailed_explanation

printf "${LIGHT_CYAN}Do you want to use auto partitioning? ${LIGHT_RED}- All data will be ERASED! -${LIGHT_CYAN} (y/n): ${NOCOLOUR}"
yes_no
if [ "$ANSWER" == "y" ]; then

    #GPT is required for disks that are bigger than 2TiB
    if (( DISK_SIZE_TIB > 2 )); then

        PARTITION_TABLE="gpt"
    fi

    #Sizing                                             #Scheme used
    #BIOS Grub - 1mib
    #EFI System Partition [ESP] - 512mib                https://superuser.com/questions/1310927/what-is-the-absolute-minimum-size-a-uefi-system-partition-can-be/1310938#1310938
    #Boot - 500mib
    #Swap - 8gib                                        https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
    #System - 32gib (If seperate)
    #Home - All of the available space

    #Calculate needed size
    declare -i NEEDED_SIZE=0
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        NEEDED_SIZE+=1
    elif [ "$IS_UEFI" == "true" ]; then
    
        NEEDED_SIZE+=512
    fi
    NEEDED_SIZE+=500
    NEEDED_SIZE+=8192
    NEEDED_SIZE+=32768

    #If not enough space
    if (( DISK_SIZE_MIB < NEEDED_SIZE )); then
    
        #Convert MiB to GiB
        NEEDED_SIZE=$((NEEDED_SIZE/1024))
        prompt_warning "Not enough disk space!"
        prompt_warning "Minimum needed size is $NEEDED_SIZE GiB (with merged home & system partitions)"
        failure "If you still want to install, manually partition your device with MBR org GPT and don't use auto-partitioning."
    fi

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
                                    "mkpart \"EFI System Partition\" 1mib 513mib" \
                                    "mkpart BOOT 514mib 1014mib" \
                                    "mkpart SYSTEM 1015mib -1"

            parted "$DISK" --script "set 1 boot on" \
                                    "set 1 esp on"
            
            IS_SEPERATE="true"
            IS_ESP_FORMAT="true"

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
                

                IS_SEPERATE="true"

                BOOT_PARTITION="$DISK"2
                ENCRYPT_PARTITION="$DISK"3
            else #Encrypt true, UEFI=false, partition table=mbr
            
                parted "$DISK" --script "mktable msdos" \
                                        "mkpart primary 1mib 501mib" \
                                        "mkpart primary 502mib -1"
             
                IS_SEPERATE="true"
    
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
                                        "mkpart \"EFI System Partition\" 1mib 513mib" \
                                        "mkpart BOOT 514mib 1014mib" \
                                        "mkpart SWAP 1015mib 9207mib" \
                                        "mkpart SYSTEM 9208mib 41976mib" \
                                        "mkpart HOME 41977mib -1"

                #ESP
                parted "$DISK" --script "set 1 boot on" \
                                        "set 1 esp on"
                
                IS_ESP_FORMAT="true"

                ESP="$DISK"1
                BOOT_PARTITION="$DISK"2
                SWAP_PARTITION="$DISK"3
                SYSTEM_PARTITION="$DISK"4
                HOME_PARTITION="$DISK"5
            else #Encrypt false, UEFI=true, is seperate=false
            
                parted "$DISK" --script "mktable gpt" \
                                        "mkpart \"EFI System Partition\" 1mib 513mib" \
                                        "mkpart BOOT 514mib 1014mib" \
                                        "mkpart SWAP 1015mib 9207mib" \
                                        "mkpart SYSTEM 9208mib -1"

                #ESP
                parted "$DISK" --script "set 1 boot on" \
                                        "set 1 esp on"
                    
                IS_ESP_FORMAT="true"
                
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
                                            "mkpart SWAP 504mib 8696mib" \
                                            "mkpart SYSTEM 8697mib 41465mib" \
                                            "mkpart HOME 41466mib -1"
                    
                    parted "$DISK" --script "set 1 bios_grub on"
                    
                    BOOT_PARTITION="$DISK"2
                    SWAP_PARTITION="$DISK"3
                    SYSTEM_PARTITION="$DISK"4
                    HOME_PARTITION="$DISK"5
                else #Encrypt false, UEFI=false, is seperate=true, partition table=mbr
                
                    parted "$DISK" --script "mktable msdos" \
                                            "mkpart primary 1mib 501mib" \
                                            "mkpart extended 502mib -1" \
                                            "mkpart logical 503mib 8695mib" \
                                            "mkpart logical 8696mib 41464mib" \
                                            "mkpart logical 41465mib -1"
                    
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
                                            "mkpart SWAP 504mib 8696mib" \
                                            "mkpart SYSTEM 8697mib -1"
                                        
                    parted "$DISK" --script "set 1 bios_grub on"
                    
                    BOOT_PARTITION="$DISK"2
                    SWAP_PARTITION="$DISK"3
                    SYSTEM_PARTITION="$DISK"4
                else #Encrypt false, UEFI=false, is seperate=false, partition table=mbr
                
                    parted "$DISK" --script "mktable msdos" \
                                            "mkpart primary 1mib 501mib" \
                                            "mkpart extended 502mib -1" \
                                            "mkpart logical 503mib 8695mib" \
                                            "mkpart logical 8696mib -1"
                    
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
    if [ "$PARTITION_TABLE" == "other" ]; then
    
        prompt_warning "ERROR! Partition table not supported! "
        failure "Please use auto partitioning or format it with a correct table (MBR or GPT)."
    fi
    
    #Inform the user about needed partitions
    clear
    prompt_info "Needed partitions:"
    printf "\033[1A\033[2K\r"
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        prompt_different "BIOS Grub Partition"
    elif [ "$IS_UEFI" == "true" ]; then
    
        prompt_different "EFI System Partition"
    fi
    echo
    prompt_different "Boot Partition"
    echo
    prompt_different "Swap Partition"
    echo
    prompt_different "System Partition"
    echo
    prompt_different "Home Partition (optional)"
    echo

    #Look for LUKS partitions
    declare LUKS=""
    LUKS=$(lsblk "$DISK" -o path,fstype | grep "crypto_LUKS" | awk '{print $1}')

    if [ -n "$LUKS" ]; then

        declare -i current_=0
    
        prompt_info "LUKS partitions found!"
        printf "\033[1A"
        prompt_different "$LUKS"
        echo
        echo
    
        for i in $LUKS; do
    
            prompt_question "Do you want to open $i (y/n): "
            yes_no
    
            if [ "$ANSWER" == "y" ]; then
    
                current_+=1
    
                prompt_info "Opening $i..."
                cryptsetup open "$i" LUKS$current_
            fi
        done
    else
    
        sleep 7s
    fi


    #BIOS GRUB partition
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        declare -i last_partition=0
        declare PRINT=""
        
        PRINT=$(parted --script "$DISK" "print")
        last_partition=$(echo "$PRINT" | awk '{print $1}' | tail -1)
        
        clear
        echo "$PRINT"
        
        printf "${LIGHT_CYAN}Please specify the number for the Grub parition ${LIGHT_RED}(1mib partition advised)${LIGHT_CYAN}: ${NOCOLOUR}"
        number_check "$last_partition"
        
        parted "$DISK" --script "set $NUMBER_CHECK bios_grub on"
        sleep 2s
    fi

    
    #Print the disk
    clear
    lsblk "$DISK" -o +path,partlabel

    #Get ESP
    if [ "$IS_UEFI" == "true" ]; then
        
        #Make is_esp directory and don't prompt for error if exist
        mkdir -p /mnt/is_esp
    
        IS_ESP_FORMAT="false"
    
        while true; do
            
            prompt_path "EFI System partiton: "
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
                prompt_warning "You can always quit with Ctrl-C or Ctrl-Z if needed."
                sleep 2s
            fi
        done
    fi
    
    #Get Boot
    prompt_path "a Boot partition: "
    partition_check
    BOOT_PARTITION="$PART_CHECK"
    
    #Get Swap
    prompt_path "a Swap partition: "
    partition_check
    SWAP_PARTITION="$PART_CHECK"

    #Is seperate?
    prompt_different "Does home and system partitions seperate? (y/n): "
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        IS_SEPERATE="true"
    
        #Get System
        prompt_path "a System partition: "
        partition_check
        SYSTEM_PARTITION="$PART_CHECK"
    
        #Home
        prompt_path "a Home partition: "
        partition_check
        HOME_PARTITION="$PART_CHECK"
    else

        IS_SEPERATE="false"
    
        #Get Systen
        prompt_path "a System partition: "
        partition_check
        SYSTEM_PARTITION="$PART_CHECK"
    fi
fi

#Wait before using parted again in case the disk is old
sleep 5s

#Print current configuration
clear
prompt_info "Current configuration:"
parted "$DISK" --script "print"
sleep 7s


# ---------------------------------- Encrypt --------------------------------- #
#Scheme used:
#https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS

if [ "$IS_ENCRYPT" == "true" ]; then

    clear
    prompt_info "Encrypting $ENCRYPT_PARTITION..."
    
    #Check if cryptsetup exited normally
    while ! cryptsetup luksFormat "$ENCRYPT_PARTITION"; do

        prompt_warning "Try again."
        prompt_warning "You can always quit with Ctrl-C or Ctrl-Z if needed."
        sleep 3s
        clear
    done

    prompt_info "Opening $ENCRYPT_PARTITION..."
    cryptsetup open "$ENCRYPT_PARTITION" cryptlvm

    #Prepare logical volumes
    clear
    prompt_info "Making logical volumes..."
    pvcreate /dev/mapper/cryptlvm
    vgcreate "$VOLGROUP" /dev/mapper/cryptlvm
    lvcreate -L 8G "$VOLGROUP" -n swap
    lvcreate -L 32G "$VOLGROUP" -n root
    lvcreate -l 100%FREE "$VOLGROUP" -n home

    SYSTEM_PARTITION="/dev/mapper/$VOLGROUP-root"
    HOME_PARTITION="/dev/mapper/$VOLGROUP-home"
    SWAP_PARTITION="/dev/mapper/$VOLGROUP-swap"
fi


# ------------------------------- File Systems ------------------------------- #
prompt_info "Making file systems..."

if output=$([ "$IS_UEFI" == "true" ] && [ "$IS_ESP_FORMAT" == "true" ]); then

    mkfs.fat "$ESP" || failure "Cannot make file system in $ESP."
fi

if [ "$IS_SEPERATE" == "true" ]; then

    mkfs.ext4 -F -F "$BOOT_PARTITION" || failure "Cannot make file system in $BOOT_PARTITION."
    mkfs.ext4 -F -F "$SYSTEM_PARTITION" || failure "Cannot make file system in $SYSTEM_PARTITION."
    mkfs.ext4 -F -F "$HOME_PARTITION" || failure "Cannot make file system in $HOME_PARTITION."
    mkswap -f "$SWAP_PARTITION" || failure "Cannot make file system in $SWAP_PARTITION."
    swapon "$SWAP_PARTITION" || failure "Cannot activate swap on $SWAP_PARTITION."

elif [ "$IS_SEPERATE" == "false" ]; then

    mkfs.ext4 -F -F "$BOOT_PARTITION" || failure "Cannot make file system in $BOOT_PARTITION."
    mkfs.ext4 -F -F "$SYSTEM_PARTITION" || failure "Cannot make file system in $SYSTEM_PARTITION."
    mkswap -f "$SWAP_PARTITION" || failure "Cannot make file system in $SWAP_PARTITION."
    swapon "$SWAP_PARTITION" || failure "Cannot activate swap on $SWAP_PARTITION."
else

    failure "Script is not running properly!"
fi


# --------------------------------- Mounting --------------------------------- #
prompt_info "Mounting..."

#System
mkdir -p "/mnt/$DEVICE"
mount "$SYSTEM_PARTITION" "/mnt/$DEVICE"

#ESP
#https://wiki.archlinux.org/title/EFI_system_partition#Mount_the_partition
if [ "$IS_UEFI" == "true" ]; then

    mkdir -p "/mnt/$DEVICE/efi"
    mount "$ESP" "/mnt/$DEVICE/efi"
fi

#Boot
mkdir -p "/mnt/$DEVICE/boot"
mount "$BOOT_PARTITION" "/mnt/$DEVICE/boot"

#Home
if [ "$IS_SEPERATE" == "true" ]; then
    
    mkdir -p "/mnt/$DEVICE/home"
    mount "$HOME_PARTITION" "/mnt/$DEVICE/home"
fi


# ----------------------------- Package Selection ---------------------------- #
pkg_select "$ADDITIONAL_PACKAGES"
PACKAGES+="$PKG_SELECT"

pkg_select "$ADDITIONAL_AUR_PACKAGES"
AUR_PACKAGES+="$PKG_SELECT"


print_packages


# ----------------------------- Greeter Selection ---------------------------- #
#Print Greeters
choose_one "Greeter packages are: " "$GREETER" "$GREETER_AUR"
SELECTED_GREETER="$SELECTION"

print_packages

# -------------------------- Video Driver Selection -------------------------- #
#Get model
prompt_info "Your graphics card model is:"
lspci -v | grep -A1 -e VGA -e 3D
echo

choose_one "Driver Packages are: " "$VIDEO_DRIVER" "$VIDEO_DRIVER_AUR"
SELECTED_VIDEO_DRIVER="$SELECTION"

print_packages


#Sort mirrorslist
check_connection
printf "${LIGHT_GREEN}Do you want to sort the mirror list to make the downloads faster?${LIGHT_RED} - might take a while - ${LIGHT_GREEN}(y/n): ${NOCOLOUR}"
yes_no
if [ "$ANSWER" == "y" ]; then

    clear
    prompt_info "Sorting mirror list..."
    reflector --verbose --sort rate --protocol https --latest 55 --save /etc/pacman.d/mirrorlist
fi


# ------------------------------- Installation ------------------------------- #
check_connection
echo
for i in {5..0}; do

    prompt_warning "Installation will start in: "
    printf "${LIGHT_CYAN}$i${NOCOLOUR}\033[0K\r"
    sleep 1s
done

#pacstrap "/mnt/$DEVICE" $CORE_PACKAGES $PACKAGES $BOOTLOADER_PACKAGES $DISPLAY_MANAGER $DE_PACKAGES $DE_DEPENDENT_PACKAGES

#Generate fstab
prompt_info "Generating fstab..."
#genfstab -U "/mnt/$DEVICE" >> "/mnt/$DEVICE/etc/fstab"


# ---------------------------------------------------------------------------- #
#                                     Setup                                    #
# ---------------------------------------------------------------------------- #
function setup () {

    #Timezone
    declare LIST=""
    declare LIST_RAW=""
    declare TIMEZONE=""
    declare max=""
    
    LIST_RAW="$(timedatectl list-timezones)"
    LIST="$(echo "$LIST_RAW" | cat -n)"
    max="$(echo "$LIST" | tail -1 | awk '{print $1}')"
    
    prompt_different "Please find your timezone in the list."
    echo
    printf "${YELLOW}About to list timezones... (you can quit the listing mode with${LIGHT_RED} q ${YELLOW}& use${LIGHT_RED} pg up-down${YELLOW})${NOCOLOUR}"
    prompt_warning "Press any key to continue..."
    read -e -r TMP
    
    echo "$LIST" | less
    prompt_question "Please specify your timezone: "
    number_check "max"
    
    TIMEZONE=$(echo "$LIST_RAW" | head -"$NUMBER_CHECK" | tail -1)
    prompt_info "Setting timezone..."
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    
    #Locales
    prompt_different "Please uncomment the needed locales (en_US.UTF-8 UTF-8, YOUR_LOCALE) in the file that is going to open."
    echo
    prompt_different "Press Ctrl-S to save and Ctrl-X to exit."
    echo
    prompt_warning "Press any key to continue..."
    read -e -r TMP
    prompt_info "Generating locales..."
    nano /etc/locale.gen
    loale-gen
    
    #Locale.conf
    prompt_info "Making /etc/locale.conf file..."
    printf "LANG=en_US.UTF-8" > /etc/locale.conf
    
    #Keymap
    prompt_question "Have you set your keyboard layout? (y/n): "
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        prompt_different "Please write your keyboard layout in the file that is going to open. (ex: KEYMAP=de-latin1)"
        echo
        prompt_different "Press Ctrl-S to save and Ctrl-X to exit."
        echo
        prompt_warning "Press any key to continue..."
        read -e -r TMP
        printf "KEYMAP=" > /etc/vconsole.conf
        nano /etc/vconsole.conf
    fi
    
    #Hostname
    prompt_info "Generating /etc/hostname..."
    printf "%s" "$DEVICE" > /etc/hostname
    
    #Hosts
    prompt_info "Generating /etc/hosts..."
    printf "127.0.0.1      localhost\n"
    printf "::1            localhost\n"
    printf "127.0.1.1      %s.localdomain    %s" "$DEVICE" "$DEVICE"
    
    #Initramfs
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        prompt_info "Arranging /etc/mkinitcpio.conf"
        declare MKINITCPIO=""
        MKINITCPIO=$(sed "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)/g" /etc/mkinitcpio.conf)
        
        sleep 1s
        
        if [ -n "$MKINITCPIO" ]; then
        
            prompt_info "Backing up /etc/mkinitcpio.conf to /etc/mkinitcpio.conf.backup..."
            mv /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
            echo "$MKINITCPIO" > /etc/mkinitcpio.conf
        else
        
            prompt_warning "Cannot modify /etc/mkinitcpio.conf!"
            prompt_warning "You have to modify it manually."
            
            echo "HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)" >> /etc/mkinitcpio.conf
            
            prompt_different "Needed format appended to the file."
            echo
            prompt_different "Just comment the first 'HOOKS=...' line, and uncomment the second one."
            echo
            prompt_warning "Press any key to continue..."
            read -e -r TMP
            
            nano /etc/mkinitcpio.conf
        fi
    fi
    
    #Grub
    prompt_info "Installing grub..."
    grub-install --target=i386-pc "$DISK"
    
    #Configure grub
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        prompt_info "Arranging /etc/default/grub..."
        declare ENCRYPT_UUID=""
        ENCRYPT_UUID=$(blkid "$ENCRYPT_PARTITION" | awk '{print $2}' | sed s/\"//g)
        
        declare CMDLINE=""
        CMDLINE=$(sed "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=$ENCRYPT_UUID:cryptlvm root=/dev/$VOLGROUP/root\"|g" /etc/default/grub)
        
        sleep 1s
        
        if [ -n "$CMDLINE" ]; then
            
            prompt_info "Backing up /etc/default/grub to /etc/default/grub.backup..."
            mv /etc/default/grub /etc/default/grub.backup
            echo "$CMDLINE" > /etc/default/grub
        else
        
            prompt_warning "Cannot modify /etc/default/grub!"
            prompt_warning "You have to modify it manually."
            
            echo "GRUB_CMDLINE_LINUX=\"cryptdevice=$ENCRYPT_UUID:cryptlvm root=/dev/$VOLGROUP/root\"" >> /etc/default/grub
            
            prompt_different "Needed format appended to the file."
            echo
            prompt_different "Just comment the first 'GRUB_CMDLINE_LINUX=...' line, and uncomment the second one."
            echo
            prompt_warning "Press any key to continue..."
            read -e -r TMP
            
            nano /etc/default/grub
        fi
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
    
    #Enable sudo group
    prompt_info "Enabling sudo group..."
    declare SUDOERS=""
    SUDOERS=$(sed "s/# %sudo/%sudo/g" /etc/sudoers)
    
    sleep 1s
    
    if [ -n "$SUDOERS" ]; then
        
        prompt_info "Backing up /etc/sudoers to /etc/sudoers.backup"
        mv /etc/sudoers /etc/sudoers.backup
        echo "$SUDOERS" > /etc/sudoers
    else
    
        prompt_warning "Cannot modify /etc/sudoers!"
        prompt_warning "You have to modify it manually."
        
        prompt_different "Just uncomment the '# %sudo...' line."
        echo
        prompt_warning "Press any key to continue..."
        read -e -r TMP
        
        nano /etc/sudoers
    fi
    groupadd sudo
    
    #Add user
    clear
    prompt_question "Enter a name for new user: "
    read -e -r USER_NAME
    while ! useradd -m -G sudo "$USER_NAME"; do

        prompt_warning "Try again."
    done
    while ! passwd "$USER_NAME"; do

    prompt_warning "Try again."
    done
    
    #Setting root password
    printf "Root "
    while ! passwd root; do

    prompt_warning "Try again."
    done
    
    #Pass username to second phase
    printf "%s" "$USER_NAME" > /user_name.txt
    
    prompt_warning "Installation complete!"
}

#Export variables to be able to use in chroot
export NUMBER_CHECK="$NUMBER_CHECK"
export ANSWER="$ANSWER"
export DEVICE="$DEVICE"
export IS_ENCRYPT="$IS_ENCRYPT"
export DISK="$DISK"
export ENCRYPT_PARTITION="$ENCRYPT_PARTITION"
export VOLGROUP="$VOLGROUP"

export YELLOW="$YELLOW"
export LIGHT_RED="$LIGHT_RED"
export LIGHT_CYAN="$LIGHT_CYAN"
export LIGHT_GREEN="$LIGHT_GREEN"
export NOCOLOUR="$NOCOLOUR"

#Export functions to be able to use in chroot
export -f number_check
export -f yes_no
export -f prompt_info
export -f prompt_warning
export -f prompt_question
export -f prompt_different

export -f setup

arch-chroot "/mnt/$DEVICE" /bin/bash -c "setup"

#Setup second phase
setup_second_phase

#Finish
prompt_warning "Please run ./setup_second_phase.sh command!"
