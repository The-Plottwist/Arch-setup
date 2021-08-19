#!/bin/bash

# -------------------------------- COPYRIGHT ------------------------------- #
#    <A Complete Arch Linux Installer>
#    
#    Copyright (C) <2021> <Fatih Yegin>
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


#Followed guide:
#https://wiki.archlinux.org/title/Installation_guide


# ---------------------------------- Globals --------------------------------- #

declare PROGRAM_NAME=""
PROGRAM_NAME="arch-setup.sh"

declare DISK_CHECK=""
declare PART_CHECK=""
declare NUMBER_CHECK=""
declare PKG_SELECT=""
declare ANSWER=""
declare SELECTION=""

declare MOUNT_PATH=""
declare GRUB_ARGS=""

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


#All additional packages will be asked to the user.
#They will be added to the original set if accepted.
declare CORE_PACKAGES="base linux linux-firmware"

declare PACKAGES="os-prober lvm2 sudo base-devel screen git python python-pip cpupower thermald dhcpcd dhclient flatpak parted htop lshw man-db man-pages texinfo mc nano net-tools network-manager-applet networkmanager nm-connection-editor ntfs-3g pacman-contrib unrar unzip p7zip usbutils wget xdg-user-dirs firefox deluge deluge-gtk foliate gimp inkscape keepassxc libreoffice-fresh vlc"

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
declare LIGHT_BLUE='\033[1;34m'
declare PURPLE='\033[0;35m'
#declare LIGHT_PURPLE='\033[1;35m'
#declare CYAN='\033[0;36m'
declare LIGHT_CYAN='\033[1;36m'
#declare LIGHT_GRAY='\033[0;37m'
#declare WHITE='\033[1;37m'
declare NOCOLOUR='\033[0m'


# --------------------------------- Functions -------------------------------- #
#Signal handling
trap clean_up SIGHUP SIGINT SIGTERM

function clean_up () {

    echo
    echo
    prompt_warning "Signal received..."
    
    rm -f "$MOUNT_PATH$TMP_FILE" &> /dev/null
    rm -f "/tmp/$PROGRAM_NAME.lock"
    
    Umount_
    
    prompt_warning "Exiting..."
    exit "130"
}

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


function Umount_ () {

    if [ -z "$DISK" ]; then return; fi
    
    declare MOUNTPOINTS_U=""
    declare SWAPS_U=""
    declare CRYPT_U=""
    declare LVM_U=""
    declare LUKS_U=""
    
    
    prompt_info "Unmounting please wait..."
    
    #Umount
    MOUNTPOINTS_U=$(lsblk -o mountpoints "$DISK" | grep "/" | sort --reverse)
    if [ -n "$MOUNTPOINTS_U" ]; then
    
        for i in $MOUNTPOINTS_U; do
    
               umount "$i"
        done
    
        sleep 3s
    fi
    
    #Swapoff
    SWAPS_U=$(lsblk -o mountpoints,path "$DISK" | grep "\[SWAP\]" | awk '{print $2}')
    if [ -n "$SWAPS_U" ]; then
    
        for i in $SWAPS_U; do
                    
            swapoff "$i"
        done
    
        sleep 3s
    fi
    
    
    CRYPT_U=$(lsblk -o type,path "$DISK")
    
    #Logical volumes
    LVM_U=$(echo "$CRYPT_U" | grep -w "lvm" | awk '{print $2}')
    if [ -n "$LVM_U" ]; then
        
        for i in $LVM_U; do
            
            cryptsetup close "$i"
        done
    
        sleep 3s
    fi
    
    #LUKS partitions
    LUKS_U=$(echo "$CRYPT_U" | grep -w "crypt" | awk '{print $2}')
    if [ -n "$LUKS_U" ]; then
        
        for i in $LUKS_U; do
            
            cryptsetup close "$i"
        done

        sleep 3s
    fi

    #Inform the kernel
    prompt_info "Informing kernel about partition changes..."
    partprobe
}


function Exit_ () {

    rm -f "$MOUNT_PATH$TMP_FILE" &> /dev/null
    rm -f "/tmp/$PROGRAM_NAME.lock"

    Umount_

    exit "$1"
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

#If no arguments passed, read it from the user.
#And check the input. If user entered wrongly
#loop until correct answer is get else return either 0 -true- or 12 -false-
function disk_check () {

    declare INPUT=""
    declare IS_ARGUMENT=""
    
    if [ -n "$1" ]; then
    
        IS_ARGUMENT="true"
        INPUT="$1"
    else
        
        IS_ARGUMENT="false"
        read -e -r INPUT
    fi
    

    #Use awk to remove unnecessary spaces
    while ! output=$(lsblk -o type,path | awk '{print $1,$2}'| grep -x "disk $INPUT"); do
    
        if [ "$IS_ARGUMENT" == "false" ]; then
            
            prompt_warning "The disk '$INPUT' couldn't found."
            printf "${LIGHT_RED}Please try again: ${NOCOLOUR}"
            read -e -r INPUT
        else
        
            return 12
        fi
    done

   DISK_CHECK="$INPUT"
}


#If no arguments passed, read it from the user.
#And check the input. If user entered wrongly
#loop until correct answer is get else return either 0 -true- or 13 -false-
function partition_check () {

    declare INPUT=""
    declare IS_ARGUMENT=""
    
    if [ -n "$1" ]; then
    
        IS_ARGUMENT="true"
        INPUT="$1"
    else
        
        IS_ARGUMENT="false"
        read -e -r INPUT
    fi

    #Use awk to remove unnecessary spaces
    while ! output=$(lsblk -o type,path "$DISK" | awk '{print $1,$2}' | grep -v "disk" | grep "$INPUT"); do
    
        if [ "$IS_ARGUMENT" == "false" ]; then
            
            prompt_warning "Partition '$INPUT' couldn't found."
            printf "${LIGHT_RED}Please try again: ${NOCOLOUR}"
            read -e -r INPUT
        else
        
            return 13
        fi
    done

   PART_CHECK="$INPUT"
}


#If no arguments passed, read it from the user.
#And check the input. If user entered wrongly
#loop until correct answer is get else return either 0 -true- or 14 -false-
function number_check () {

    declare max_=0
    
    #Max_ cannot be zero nor char
    if output=$([[ ! $1 =~ ^[0-9]+$ ]] || (( $1 == 0 )) ); then
    
        failure "number_check INTERNAL ERROR! Wrong input received. (\$1: $1) -Revise the code-"
    else
    
        max_=$1
    fi
    
    
    declare IS_ARGUMENT=""
    if [ -n "$2" ]; then
    
        IS_ARGUMENT="true"
        NUMBER_CHECK="$2"
    else
        
        IS_ARGUMENT="false"
        read -e -r NUMBER_CHECK
    fi
    
    while output=$( [[ ! $NUMBER_CHECK =~ ^[0-9]+$ ]] || (( NUMBER_CHECK > max_ )) || (( NUMBER_CHECK == 0 )) ); do
    
        if [ "$IS_ARGUMENT" == "false" ]; then
            
            prompt_warning "Wrong number!"
            prompt_question "Please re-enter: "
            read -e -r NUMBER_CHECK
        else
        
            return 14
        fi
    done
}


function print_packages () {

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
    
    printf "${LIGHT_BLUE}Greeter: ${LIGHT_CYAN}%s${NOCOLOUR}" "$SELECTED_GREETER"
    echo
    
    printf "${LIGHT_BLUE}Video Driver: ${LIGHT_CYAN}%s${NOCOLOUR}" "$SELECTED_VIDEO_DRIVER"
    echo
    echo
}


#Takes additional package sets as an argument
#And asks the user to include each of the packages in the original set or not
function pkg_select () {

    declare SELECTION_=""
    print_packages

    for i in $1; do
    
        printf "${LIGHT_GREEN}Do you want to install${LIGHT_RED} %s${LIGHT_GREEN}? (y/n)${LIGHT_GREEN}: ${NOCOLOUR}" "$i"
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
    prompt_question "Please choose one: "
    number_check "$max"
    
    #Include it in the installation
    declare -i current=0
    for i in $OFFICIAL_PKGS $AUR_PKGS; do
    
        current+=1
        if [ "$current" == "$NUMBER_CHECK" ]; then
        
            if (( current < aur_part )); then
            
                PACKAGES+=" $i"
                SELECTION="$i"
                break
            elif (( current >= aur_part )); then
            
                AUR_PACKAGES+=" $i"
                SELECTION="$i"
                break
            fi
        fi
    done
}

# ---------------------------------------------------------------------------- #
#                    Second Phase (Will be used at the end)                    #
# ---------------------------------------------------------------------------- #

#Generate a file called "setup-second-phase.sh"
#Warning: Mix use of double quotes ("") and single quotes ('')
function setup-second-phase () {

#Inform the user (still in first phase)
prompt_info "Generating setup-second-phase.sh..."

#Below is the code of "setup-second-phase.sh"
{

echo "#!/bin/bash


# ---------------------------------------------------------------------------- #
#                      ! This is an Auto Generated file !                      #
# ---------------------------------------------------------------------------- #

declare PROGRAM_NAME=\"\"
PROGRAM_NAME=\"setup-second-phase.sh\"

#Colours for colourful output
declare LIGHT_RED='\033[1;31m'
declare YELLOW='\033[1;33m'
declare LIGHT_GREEN='\033[1;32m'
declare NOCOLOUR='\033[0m' #No Colour

declare MOUNT_PATH=\"$MOUNT_PATH\"
declare DISK=\"$DISK\"

declare IS_ENCRYPT=\"$IS_ENCRYPT\"
declare ENCRYPT_PARTITION=\"$ENCRYPT_PARTITION\"
declare SWAP_PARTITION=\"$SWAP_PARTITION\"
declare HOME_PARTITION=\"$HOME_PARTITION\"
declare SYSTEM_PARTITION=\"$SYSTEM_PARTITION\"

declare USER_NAME=\"$USER_NAME\"
declare AUR_PACKAGES=\"$AUR_PACKAGES\"
declare SELECTED_GREETER=\"$SELECTED_GREETER\"
declare SERVICES=\"$SERVICES\"


# ---------------------------------------------------------------------------- #
#                                   Functions                                  #
# ---------------------------------------------------------------------------- #

#Signal handling
trap clean_up SIGHUP SIGINT SIGTERM

function clean_up () {

    prompt_warning \"Signal received!\"
    prompt_warning \"Exiting...\"
    Exit_ \"155\"
}

function check_connection () {

    { ping wiki.archlinux.org -c 1 &>> /dev/null; } || failure \"No internet connection!\"
}
"

echo 'function Umount_ () {

    declare MOUNTPOINTS_U=""
    declare SWAPS_U=""
    declare CRYPT_U=""
    declare LVM_U=""
    declare LUKS_U=""
    
    MOUNTPOINTS_U=$(lsblk -o mountpoints "$DISK" | grep "/" | sort --reverse)
    SWAPS_U=$(lsblk -o mountpoints,path "$DISK" | grep "\[SWAP\]" | awk '\''{print $2}'\'')
    CRYPT_U=$(lsblk -o type,path "$DISK")
    LVM_U=$(echo "$CRYPT_U" | grep -w "lvm" | awk '\''{print $2}'\'')
    LUKS_U=$(echo "$CRYPT_U" | grep -w "crypt" | awk '\''{print $2}'\'')
    
    if output=$([ -n "$MOUNTPOINTS_U" ] && [ -n "$SWAPS_U" ] && [ -n "$CRYPT_U" ] && [ -n "$LVM_U" ] && [ -n "$LUKS_U" ]); then
    
        prompt_info "Unmounting please wait..."
    
        #Umount
        if [ -n "$MOUNTPOINTS_U" ]; then
    
            for i in $MOUNTPOINTS_U; do
    
                   umount "$i"
            done
    
            sleep 3s
        fi
    
        #Swapoff
        if [ -n "$SWAPS_U" ]; then
    
            for i in $SWAPS_U; do
                    
                swapoff "$i"
            done
    
            sleep 3s
        fi
    
        #Logical volumes
        if [ -n "$LVM_U" ]; then
        
            for i in $LVM_U; do
            
                cryptsetup close "$i"
            done
    
            sleep 3s
        fi
    
        #LUKS partitions
        if [ -n "$LUKS_U" ]; then
        
            for i in $LUKS_U; do
            
                cryptsetup close "$i"
            done
    
            sleep 3s
        fi
    fi

    #Inform the kernel
    prompt_info "Informing kernel of partition changes..."
    partprobe
}
'

echo 'function Exit_ () {

    #Umount_

    rm -f "/tmp/$PROGRAM_NAME.lock"

    exit $1
}

function prompt_warning () {

    printf "${LIGHT_RED}%s${NOCOLOUR}" "$1"
    echo
}
function prompt_info () {

    echo
    printf "${YELLOW}%s${NOCOLOUR}" "$1"
    echo
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

        prompt_info \"Cloning yay...\"
        cd \"/home/\$USER_NAME\" || failure \"Cannot change directory to /home/\$USER_NAME\"
        mkdir -p Git-Hub || failure \"/home/\$USER_NAME/Git-Hub directory couldn't made.\"
        cd Git-Hub || failure \"Cannot change directory to /home/\$USER_NAME/Git-Hub\"

        git clone https://aur.archlinux.org/yay.git || failure \"Cannot clone yay.\"
    }

    #Generating home directories
    prompt_info \"Generating home directories...\"
    xdg-user-dirs-update
    
    #Install go for yay
    prompt_info \"Installing go for aur helper... -yay-\"
    pacman -S --noconfirm go
    
    #Export variables to use it in the user's shell
    export USER_NAME=\"\$USER_NAME\"
    
    #Export functions to call it in the user's shell
    export -f clone_yay
    export -f check_connection

    #Clone yay
    su \"\$USER_NAME\" /bin/bash -c clone_yay || Exit_ \$?

    #Install yay.
    prompt_info \"Installing yay...\"
    cd \"/home/\$USER_NAME/Git-Hub/yay\" || failure \"Cannot change directory to /home/\$USER_NAME/Git-Hub/yay\"
    sudo -u \"\$USER_NAME\" makepkg -si --noconfirm || failure \"Error Cannot install yay!\"
    
    #Download pkgbuilds
    prompt_info \"Downloading pkgbuilds...\"
    mkdir -p \"/home/\$USER_NAME/.cache/yay\" || { prompt_warning \"Cannot make /home/\$USER_NAME/.cache/yay directory!\"; prompt_warning \"Instead, downloading to /home/\$USER_NAME\"; }
    
    if [ -d \"/home/\$USER_NAME/.cache/yay\" ]; then
        
        cd \"/home/\$USER_NAME/.cache/yay\" || failure \"Cannot change directory to /home/\$USER_NAME/.cache/yay\"
    else
        
        cd \"/home/\$USER_NAME/\" || failure \"Cannot change directory to /home/\$USER_NAME/\"
    fi
    yay --getpkgbuild \$AUR_PACKAGES || failure \"Cannot download pkgbuilds!\"

    #Arrange permissions
    chown -R \"\$USER_NAME:\$USER_NAME\" \"/home/\$USER_NAME/.cache/\"
"

echo '    #Install aur packages
    prompt_info "Installing aur packages..."
    cd "/home/$USER_NAME/.cache/yay"
    for i in *; do

        cd "$i"
        sudo -u "$USER_NAME" makepkg -si --noconfirm
        cd ..
    done
'

echo "    #Check if /etc/lightdm.conf exists
    if [ -f \"/etc/lightdm/lightdm.conf\" ]; then
    
        if pacman -Q \"\$SELECTED_GREETER\"; then
        
            prompt_info \"Enabling \$SELECTED_GREETER...\"
            declare LIGHTDM_CONF=\"\"
            LIGHTDM_CONF=\$(sed \"s/#greeter-session=example-gtk-gnome/greeter-session=\$SELECTED_GREETER/g\" /etc/lightdm/lightdm.conf)
            sleep 1s
            if [ -n \"\$LIGHTDM_CONF\" ]; then
            
                prompt_info \"Backing up /etc/lightdm/lightdm.conf to /etc/lightdm/lightdm.conf.backup...\"
                mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
                echo \"\$LIGHTDM_CONF\" > /etc/lightdm/lightdm.conf
            else
            
                prompt_warning \"Cannot modify /etc/lightdm/lightdm.conf file.\"
                prompt_warning \"You have to modify it manually.\"
                printf \"\${LIGHT_RED}greeter-session=example-gtk-gnome \${LIGHT_GREEN}should be equal to \${LIGHT_RED}greeter_session=\$SELECTED_GREETER \${LIGHT_GREEN}-which is under the [Seat:*] section-\${NOCOLOUR}\"
                
                prompt_warning \"Press enter to continue...\"
                read -e -r TMP
            fi
        else
        
            prompt_warning \"\$SELECTED_GREETER is not installed!\"
            prompt_warning \"Skipping activation.\"
            prompt_warning \"You have to modify /etc/lightdm/lightdm.conf file manually after installing it.\"
            printf \"\${LIGHT_RED}greeter-session=example-gtk-gnome \${LIGHT_GREEN}should be equal to \${LIGHT_RED}greeter_session=\$SELECTED_GREETER \${LIGHT_GREEN}-which is under the [Seat:*] section-\${NOCOLOUR}\"
            
            prompt_warning \"Press enter to continue...\"
            read -e -r TMP
        fi
        
        prompt_warning \"For troubleshooting about lightdm, follow this link: https://wiki.archlinux.org/title/LightDM#Troubleshooting\"
        sleep 5s
    fi

    #Enabling services
    prompt_info \"Enabling services...\"
    for i in \$SERVICES; do
        
        systemctl enable \$i || { prompt_warning \"Cannot enable \$i service!\"; echo \"\"; echo \"\$i\" >> /\$HOME/disabled_services.txt; prompt_warning \"Service added to /\$HOME/disabled_services.txt, Please enable it manually.\"; }
    done

    #Generate initramfs
    prompt_info \"Generating initramfs...\"
    mkinitcpio -P
    
    #Return home
    cd \"/home/\$USER_NAME\"

    prompt_warning \"AUR configuration complete!\"
}
"

echo '
# ---------------------------------------------------------------------------- #
#                           Second Phase Starts Here                           #
# ---------------------------------------------------------------------------- #

'

echo '#Lock file
if [ -f "/tmp/$PROGRAM_NAME.lock" ]; then

    prompt_warning "Another instance is already running!"
    prompt_warning "If you think this is a mistake, delete /tmp/$PROGRAM_NAME.lock"
    prompt_warning "Exiting..."
    exit 1
else

    touch "/tmp/$PROGRAM_NAME.lock"
fi

#Exporting variables to be able to use in chroot
export LIGHT_RED="$LIGHT_RED"
export YELLOW="$YELLOW"
export NOCOLOUR="$NOCOLOUR"

export USER_NAME="$USER_NAME"
export AUR_PACKAGES="$AUR_PACKAGES"
export SELECTED_GREETER="$SELECTED_GREETER"
export SERVICES="$SERVICES"
'

echo "#Export functions to be able to use in chroot
export -f prompt_info
export -f prompt_warning
export -f check_connection
export -f failure
export -f Exit_
export -f aur

#Run aur function
arch-chroot \"\$MOUNT_PATH\" /bin/bash -c \"aur\" || Exit_ \$?

#Activate time synchronization
prompt_info \"Activating time synchronization...\"
timedatectl set-ntp true

Umount_

printf \"\${LIGHT_GREEN}ARCH SETUP FINISHED!!\${NOCOLOUR}\"
echo
printf \"\${LIGHT_GREEN}You can safely reboot now.\${NOCOLOUR}\"
echo

Exit_
"

} > setup-second-phase.sh

chmod +x setup-second-phase.sh

}



# ---------------------------------------------------------------------------- #
#                                  First Phase                                 #
# ---------------------------------------------------------------------------- #

#This script assumes keyboard layout has already been set

#Lock file
if [ -f "/tmp/$PROGRAM_NAME.lock" ]; then

    prompt_warning "Another instance is already running!"
    prompt_warning "If you think this is a mistake, delete /tmp/$PROGRAM_NAME.lock"
    prompt_warning "Exiting..."
    exit 1
else

    touch "/tmp/$PROGRAM_NAME.lock"
fi

#ASCII art
#http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=Arch%20Setup
clear
echo
echo
echo
prompt_question "
               █████╗ ██████╗  ██████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ 
              ██╔══██╗██╔══██╗██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
              ███████║██████╔╝██║     ███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝
              ██╔══██║██╔══██╗██║     ██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
              ██║  ██║██║  ██║╚██████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     
              ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
"
#http://patorjk.com/software/taag/#p=display&f=Kban&t=by%20The-Plottwist
prompt_info "
'||                  |''||''| '||              ' '||''|.  '||            .     .                ||           .   
 || ...  .... ...       ||     || ..     ....     ||   ||  ||    ...   .||.  .||.  ... ... ... ...   ....  .||.  
 ||'  ||  '|.  |        ||     ||' ||  .|...||    ||...|'  ||  .|  '|.  ||    ||    ||  ||  |   ||  ||. '   ||   
 ||    |   '|.|         ||     ||  ||  ||         ||       ||  ||   ||  ||    ||     ||| |||    ||  . '|..  ||   
 '|...'     '|         .||.   .||. ||.  '|...'   .||.     .||.  '|..|'  '|.'  '|.'    |   |    .||. |'..|'  '|.' 
         .. |                                                                                                    
          ''                                                                                                     
"

#Disclaimer
prompt_different "This script is for installing archlinux on an empty (or semi-empty) disk and assumes you have ALREADY SET your keyboard layout."
echo

prompt_different "You can modify this script to your needs, otherwise XFCE will be installed with a default package set."
echo

printf "${YELLOW}Keyboard Layout: ${PURPLE}https://wiki.archlinux.org/title/Installation_guide#Set_the_keyboard_layout${NOCOLOUR}"
echo
echo

printf "${ORANGE}If you encounter a problem or want to stop the command, you can press Ctrl-C to quit.${NOCOLOUR}\n"
printf "${ORANGE}Use Ctrl-Z in dire situations and reboot your system afterwards as it doesn't actually stop the script.${NOCOLOUR}\n"
echo

prompt_warning "This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License V3 for more details."
echo

#Check the internet connection before attempting anything
check_connection

#Get device name
while true; do

    prompt_question "Please enter device name: "
    read -e -r DEVICE
    prompt_question "Please re-enter: "
    read -e -r CHECK

    if [ "$DEVICE" == "$CHECK" ]; then

        VOLGROUP="$DEVICE"VolGroup
        MOUNT_PATH="$HOME/INSTALL/$DEVICE"

        mkdir -p "$MOUNT_PATH"
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

Umount_

# ---------------------------------- Is UEFI --------------------------------- #

if [ -d /sys/firmware/efi/efivars ]; then

    IS_UEFI="true"
    PACKAGES+=" efibootmgr"
    GRUB_ARGS="--target=x86_64-efi --efi-directory=/efi --bootloader-id=Archlinux"
    printf "${LIGHT_GREEN}System boot mode detected as ${LIGHT_CYAN}UEFI${NOCOLOUR}\n\n"
else

    IS_UEFI="false"
    GRUB_ARGS="--target=i386-pc $DISK"
    printf "${LIGHT_GREEN}System boot mode detected as ${LIGHT_CYAN}Legacy BIOS${NOCOLOUR}\n\n"
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


printf "${LIGHT_CYAN}Do you want to use auto partitioning? ${LIGHT_RED}-Everything will be ERASED- (y/n): ${NOCOLOUR}"
yes_no
if [ "$ANSWER" == "y" ]; then


    #GPT is required for disks that are bigger than 2TiB
    if (( DISK_SIZE_TIB > 2 )); then

        PARTITION_TABLE="gpt"
    fi

    #Sizing                                             #Schemes used

    #BIOS Grub - 1mib
    #EFI System Partition [ESP] - 512mib                https://superuser.com/questions/1310927/what-is-the-absolute-minimum-size-a-uefi-system-partition-can-be/1310938#1310938
    #Boot - 500mib
    #Swap - 8gib                                        https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS
    #System - 32gib (If seperate)
    #Home - All of the available space
    
    
    #Calculate needed size
    declare -i NEEDED_SIZE=0
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        NEEDED_SIZE+=1 #BIOS GRUB
    elif [ "$IS_UEFI" == "true" ]; then
    
        NEEDED_SIZE+=512 #ESP
    fi
    NEEDED_SIZE+=500 #BOOT
    NEEDED_SIZE+=8192 #SWAP
    NEEDED_SIZE+=32768 #SYSTEM

    #If not enough space
    if (( DISK_SIZE_MIB < NEEDED_SIZE )); then
    
        #Convert MiB to GiB
        NEEDED_SIZE=$((NEEDED_SIZE/1024))
        prompt_warning "Not enough disk space!"
        prompt_warning "Minimum needed size is $NEEDED_SIZE GiB (with merged home & system partitions)"
        failure "If you still want to install, manually partition your device with MBR org GPT and don't use auto-partitioning."
    fi

    #GPT or MBR?
    if output=$([ "$PARTITION_TABLE" != "gpt" ] && [ "$IS_UEFI" == "false" ]); then
    
        clear
        prompt_info "Two of the popular linux supported partition tables are GPT and MBR."

        prompt_different "GUID Partition Table (GPT) is a replacement for legacy Master Boot Record (MBR) partition table. -It has better features and functionality-"
        echo
        prompt_different "However, if you plan to install Windows or want it for some specific reason you can still use MBR."
        echo
        echo
        printf "${YELLOW}For additional information visit this link: ${PURPLE}https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Disks#Partition_tables${NOCOLOUR}"
        echo

        echo
        prompt_warning "Note: Some elder hardware may have issues when booting from GPT."
        echo
        prompt_question "Do you still want to use MBR? (y/n): "
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
else #Manual partition selection

    #Partition table is not suitable for linux
    if [ "$PARTITION_TABLE" == "other" ]; then
    
        prompt_warning "ERROR! Partition table not supported! "
        failure "Please use auto partitioning or format it with a correct table (MBR or GPT)."
    fi
    
    #Inform the user about needed partitions
    clear
    prompt_info "Needed partitions:"
    printf "\033[1A\033[2K\r" #Delete unnecessary carriage returns
    
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
    
        prompt_warning "In this option, encrypted partitions will not be handled automatically."
        printf "${LIGHT_RED}You need to follow one of the guides in: ${LIGHT_CYAN}https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Overview${NOCOLOUR}"
        echo
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
                cryptsetup open "$i" LUKS$current_ || failure "Error! try rebooting."
            fi

            sleep 3s
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
    
        IS_ESP_FORMAT="false"
    
        #Make is_esp directory and don't prompt for error if exist
        mkdir -p /mnt/is_esp
    
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
                prompt_warning "You can quit with Ctrl-C or Ctrl-Z if needed."
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


# -------------------------------- Encrypting -------------------------------- #
#Scheme used:
#https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS

if [ "$IS_ENCRYPT" == "true" ]; then

    clear
    prompt_info "Encrypting $ENCRYPT_PARTITION..."
    
    #Check if cryptsetup exited normally
    while ! cryptsetup luksFormat "$ENCRYPT_PARTITION"; do

        prompt_warning "Try again."
        prompt_warning "You can quit with Ctrl-C or Ctrl-Z if needed."
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

    mkfs.fat -F32 "$ESP" || failure "Cannot make a file system in $ESP."
fi

if [ "$IS_SEPERATE" == "true" ]; then

    mkfs.ext4 -F -F "$BOOT_PARTITION" || failure "Cannot make a file system in $BOOT_PARTITION."
    mkfs.ext4 -F -F "$SYSTEM_PARTITION" || failure "Cannot make a file system in $SYSTEM_PARTITION."
    mkfs.ext4 -F -F "$HOME_PARTITION" || failure "Cannot make a file system in $HOME_PARTITION."
    mkswap -f "$SWAP_PARTITION" || failure "Cannot make a file system in $SWAP_PARTITION."
    swapon "$SWAP_PARTITION" || failure "Cannot activate swap on $SWAP_PARTITION."

elif [ "$IS_SEPERATE" == "false" ]; then

    mkfs.ext4 -F -F "$BOOT_PARTITION" || failure "Cannot make a file system in $BOOT_PARTITION."
    mkfs.ext4 -F -F "$SYSTEM_PARTITION" || failure "Cannot make a file system in $SYSTEM_PARTITION."
    mkswap -f "$SWAP_PARTITION" || failure "Cannot make a file system in $SWAP_PARTITION."
    swapon "$SWAP_PARTITION" || failure "Cannot activate swap on $SWAP_PARTITION."
else

    failure "Script is not running properly!"
fi


# --------------------------------- Mounting --------------------------------- #

prompt_info "Mounting..."

#System
mkdir -p "$MOUNT_PATH"
mount "$SYSTEM_PARTITION" "$MOUNT_PATH"

#ESP
#https://wiki.archlinux.org/title/EFI_system_partition#Mount_the_partition -Third option-
if [ "$IS_UEFI" == "true" ]; then

    mkdir -p "$MOUNT_PATH/efi"
    mount "$ESP" "$MOUNT_PATH/efi"
fi

#Boot
mkdir -p "$MOUNT_PATH/boot"
mount "$BOOT_PARTITION" "$MOUNT_PATH/boot"

#Home
if [ "$IS_SEPERATE" == "true" ]; then
    
    mkdir -p "$MOUNT_PATH/home"
    mount "$HOME_PARTITION" "$MOUNT_PATH/home"
fi

printf "${LIGHT_GREEN}Mounted on ${LIGHT_CYAN}%s${NOCOLOUR}" "$MOUNT_PATH"
sleep 5s


#Package selection
pkg_select "$ADDITIONAL_PACKAGES"
PACKAGES+="$PKG_SELECT"

pkg_select "$ADDITIONAL_AUR_PACKAGES"
AUR_PACKAGES+="$PKG_SELECT"

print_packages


#Greeter selection
choose_one "Greeter packages are: " "$GREETER" "$GREETER_AUR"
SELECTED_GREETER="$SELECTION"

print_packages

#Video driver selction
#Get model
prompt_info "Your graphics card model is:"
lspci -v | grep -A1 -e VGA -e 3D
echo

choose_one "Driver Packages are: " "$VIDEO_DRIVER" "$VIDEO_DRIVER_AUR"
SELECTED_VIDEO_DRIVER="$SELECTION"

print_packages


#Sort mirrorslist
check_connection
printf "${LIGHT_GREEN}Do you want to sort the mirror list to make the downloads faster?${LIGHT_RED} -It will persist in the system but will take a while- ${LIGHT_GREEN}(y/n): ${NOCOLOUR}"
yes_no
if [ "$ANSWER" == "y" ]; then

    clear
    prompt_info "Sorting mirror list..."
    reflector --verbose --sort rate --protocol https --latest 55 --save /etc/pacman.d/mirrorlist
fi


# ---------------------------------------------------------------------------- #
#                                 Installation                                 #
# ---------------------------------------------------------------------------- #

check_connection
echo

for i in {5..0}; do

    printf "${LIGHT_RED}Installation will start in: ${LIGHT_CYAN}%s${NOCOLOUR}\033[0K\r" "$i"
    sleep 1s
done

pacstrap "$MOUNT_PATH" $CORE_PACKAGES $PACKAGES $BOOTLOADER_PACKAGES $DISPLAY_MANAGER $DE_PACKAGES $DE_DEPENDENT_PACKAGES

#Generate fstab
prompt_info "Generating fstab..."
genfstab -U "$MOUNT_PATH" >> "$MOUNT_PATH/etc/fstab"


# ---------------------------------------------------------------------------- #
#                                     Setup                                    #
# ---------------------------------------------------------------------------- #
function setup () {

    #Timezone
    declare LIST=""
    declare TIMEZONE=""
    declare -i max=0
    
    LIST="$(timedatectl list-timezones)"
    max=$(echo "$LIST" | cat -n | tail -1 | awk '{print $1}')
    
    function list_timezones {
    
        {

            printf "${LIGHT_CYAN}Ctrl-C ${LIGHT_RED}will not work hereafter.${NOCOLOUR}"
            echo
            printf "${LIGHT_GREEN}If you're dual booting with Windows, follow this link: ${LIGHT_CYAN}https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows${NOCOLOUR}"
            echo
            printf "${LIGHT_GREEN}Please find your timezone in the list. ${LIGHT_RED}(Press 'q' to quit and use '/' to search)${NOCOLOUR}"
            echo
            echo

            declare -i n=0
            for i in $LIST; do
        
                n+=1
                printf "${LIGHT_CYAN}%s ${NOCOLOUR}" "$n"
                printf "${PURPLE}%s${NOCOLOUR}\n" "$i"
            done
        } | less --raw-control-chars
    }
    
    list_timezones
    declare INPUT=""
    while true; do
    
        prompt_question "Please specify the number of your timezone -Type 'r' to re-list-: "
        read -e -r INPUT
        
        if [ "$INPUT" == "r" ]; then
        
            list_timezones
        else
        
            if number_check "$max" "$INPUT"; then
            
                break
            else
            
                prompt_warning "Wrong Number!"
            fi
        fi
    done
    
    TIMEZONE=$(echo "$LIST" | head -"$NUMBER_CHECK" | tail -1)
    prompt_info "Setting timezone..."
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    
    #Locales
    printf "${LIGHT_GREEN}Please uncomment the needed locales ${LIGHT_RED}(en_US.UTF-8 UTF-8 and YOUR_LOCALE)${LIGHT_GREEN} in the file that is going to open.${NOCOLOUR}\n"
    printf "${LIGHT_GREEN}You can press ${LIGHT_RED}Ctrl-S${LIGHT_GREEN} to save and ${LIGHT_RED}Ctrl-X${LIGHT_GREEN} to exit.${NOCOLOUR}\n"
    prompt_warning "Press enter to continue..."
    read -e -r TMP
    nano /etc/locale.gen
    clear
    
    prompt_info "Generating locales..."
    locale-gen
    
    #Locale.conf
    prompt_info "Making /etc/locale.conf file..."
    printf "LANG=en_US.UTF-8" > /etc/locale.conf
    
    #Keymap
    if [ ! -f /etc/vconsole.conf ]; then

        printf "${LIGHT_GREEN}Please write your keyboard layout in the file that is going to open. ${LIGHT_RED}(ex: KEYMAP=de-latin1)${NOCOLOUR}"
        echo
        printf "${LIGHT_GREEN}You can press ${LIGHT_RED}Ctrl-S${LIGHT_GREEN} to save and ${LIGHT_RED}Ctrl-X${LIGHT_GREEN} to exit.${NOCOLOUR}"
        echo
        prompt_warning "Press enter to continue..."
        read -e -r TMP
        nano /etc/vconsole.conf
        clear
    fi

    #Hostname
    prompt_info "Generating /etc/hostname..."
    printf "%s" "$DEVICE" > /etc/hostname
    
    #Hosts
    prompt_info "Generating /etc/hosts..."
    {
        printf "\n127.0.0.1      localhost\n"
        printf "::1            localhost\n"
        printf "127.0.1.1      %s.localdomain    %s" "$DEVICE" "$DEVICE"
    } >> /etc/hosts
    
    # --------------------------------- Initramfs -------------------------------- #
    
    declare MKINITCPIO=""
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        MKINITCPIO=$(sed "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems resume fsck)/g" /etc/mkinitcpio.conf)
    else
    
        MKINITCPIO=$(sed "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck)/g" /etc/mkinitcpio.conf)
    fi
    
    #Flexibility for read/write operations
    sleep 1s
    
    if [ -n "$MKINITCPIO" ]; then
    
        prompt_info "Backing up /etc/mkinitcpio.conf to /etc/mkinitcpio.conf.backup..."
        mv /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup
        
        prompt_info "Configuring /etc/mkinitcpio.conf..."
        echo "$MKINITCPIO" > /etc/mkinitcpio.conf
    else
    
        prompt_warning "Cannot modify /etc/mkinitcpio.conf!"
        prompt_warning "You have to modify it manually."
        
        if [ "$IS_ENCRYPT" == "true" ]; then
            echo "HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)" >> /etc/mkinitcpio.conf
        else
        
            echo "HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck)" >> /etc/mkinitcpio.conf
        fi
        
        prompt_different "Needed format appended to the file."
        echo
        prompt_different "Just add '#' to the begining of the first 'HOOKS=...' line."
        echo
        prompt_warning "Press enter to continue..."
        read -e -r TMP
        
        nano /etc/mkinitcpio.conf
        clear
    fi
    
    # -------------------------------- Boot Loader ------------------------------- #
    
    prompt_info "Installing grub..."
    grub-install $GRUB_ARGS
    
    #Configure grub
    declare CMDLINE=""
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        declare ENCRYPT_UUID=""
        ENCRYPT_UUID=$(blkid "$ENCRYPT_PARTITION" | awk '{print $2}' | sed s/\"//g)
        
        CMDLINE=$(sed "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=$ENCRYPT_UUID:cryptlvm root=/dev/$VOLGROUP/root resume=/dev/$VOLGROUP/swap\"|g" /etc/default/grub)
    else
        
        #For hibernation
        declare SWAP_UUID=""
        SWAP_UUID=$(blkid "$SWAP_PARTITION" | awk '{print $2}' | sed s/\"//g)
        
        CMDLINE=$(sed "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"resume=$SWAP_UUID\"|g" /etc/default/grub)
    fi
    
    #Flexibility for read/write operations
    sleep 1s
    
    if [ -n "$CMDLINE" ]; then
            
        prompt_info "Backing up /etc/default/grub to /etc/default/grub.backup..."
        mv /etc/default/grub /etc/default/grub.backup
        
        prompt_info "Configuring /etc/default/grub..."
        echo "$CMDLINE" > /etc/default/grub
    else
    
        prompt_warning "Cannot modify /etc/default/grub!"
        prompt_warning "You have to modify it manually."
        
        if [ "$IS_ENCRYPT" == "true" ]; then
            
            echo "GRUB_CMDLINE_LINUX=\"cryptdevice=$ENCRYPT_UUID:cryptlvm root=/dev/$VOLGROUP/root resume=/dev/$VOLGROUP/swap\"" >> /etc/default/grub
        else
        
            echo "GRUB_CMDLINE_LINUX=\"resume=$SWAP_UUID\"" >> /etc/default/grub
        fi
        
        prompt_different "Needed format appended to the file.\n"
        printf "${LIGHT_GREEN}Just add '#' to the beginning of the first ${LIGHT_RED}'GRUB_CMDLINE_LINUX='${LIGHT_GREEN} line.${NOCOLOUR}\n"
        prompt_warning "Press enter to continue..."
        read -e -r TMP
        
        nano /etc/default/grub
        clear
    fi
    prompt_info "Generating grub.cfg..."
    grub-mkconfig -o /boot/grub/grub.cfg
    
    prompt_warning "For troubleshooting about suspend/hibernate, follow this link: https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Troubleshooting"
    sleep 5s
    
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
        
        echo "${LIGHT_GREEN}Just delete the '#' ${LIGHT_RED}'# %sudo...'${LIGHT_GREEN} line.${NOCOLOUR}"
        prompt_warning "Press enter to continue..."
        read -e -r TMP
        
        nano /etc/sudoers
        clear
    fi
    groupadd sudo

    clear

    #Add user
    declare USER_NAME=""
    declare CHECK=""
    while true; do
    
        prompt_question "Enter a name for new user: "
        read -e -r USER_NAME
        
        prompt_question "Please re-enter: "
        read -e -r CHECK
        
        if [ "$USER_NAME" == "$CHECK" ]; then
        
            useradd -m -G sudo "$USER_NAME" && break
            prompt_warning "User name is not suitable!"
        else
    
            echo
            prompt_warning "Names don't match!"
            echo
        fi
    done

    while ! passwd "$USER_NAME"; do

        prompt_warning "Try again."
    done
    
    echo
    
    #Set root password
    printf "${LIGHT_RED}Root ${NOCOLOUR}"
    while ! passwd root; do

        prompt_warning "Try again."
        printf "${LIGHT_RED}Root ${NOCOLOUR}"
    done

    prompt_warning "Installation complete!"
    
    printf "%s" "$USER_NAME" > "$TMP_FILE"
}

#Script cannot make a tmp file in the freaking /tmp directory (couldn't find an elegant solution)
#The X's are replaced randomly
declare TMP_FILE=""
TMP_FILE="/bin/$(mktemp -u XXXXXXXXXXXX)"

#Export variables to be able to use in chroot
export NUMBER_CHECK="$NUMBER_CHECK"
export ANSWER="$ANSWER"
export DEVICE="$DEVICE"
export IS_ENCRYPT="$IS_ENCRYPT"
export DISK="$DISK"
export ENCRYPT_PARTITION="$ENCRYPT_PARTITION"
export SWAP_PARTITION="$SWAP_PARTITION"
export VOLGROUP="$VOLGROUP"
export GRUB_ARGS="$GRUB_ARGS"
export TMP_FILE="$TMP_FILE"

export YELLOW="$YELLOW"
export PURPLE="$PURPLE"
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

arch-chroot "$MOUNT_PATH" /bin/bash -c "setup"

#Assign User_name
declare USER_NAME=""
USER_NAME=$(cat "$MOUNT_PATH$TMP_FILE")
rm -f "$MOUNT_PATH$TMP_FILE"

#Setup second phase
setup-second-phase

#Remove lock
rm -f "/tmp/$PROGRAM_NAME.lock"

#Finish
prompt_different "Please run ./setup-second-phase.sh command!"
echo
