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



#Auto partitioning wipes hard disk entirely, therefore it is disabled by default.
#To enable, uncomment the below line
#Remember, it is at your own risk!
#declare ENABLE_AUTO_PARTITIONING="true"


#Followed guide:
#https://wiki.archlinux.org/title/Installation_guide


# ---------------------------------- Globals --------------------------------- #

declare PROGRAM_NAME=""
PROGRAM_NAME="arch-setup.sh"

declare DISK_CHECK=""
declare PART_CHECK=""
declare NUMBER_CHECK=""
declare PKG_SELECT=""
declare PKG_FIND=""
declare ANSWER=""
declare SELECTION=""

declare MOUNT_PATH=""
declare GRUB_ARGS=""

declare PARTITION_TABLE=""
declare DISK=""
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

declare KEY_LAYOUT=""
declare DEVICE=""
declare VOLGROUP=""
declare TIMEZONE=""
declare USER_NAME=""
declare USER_PASS=""
declare ROOT_PASS=""

#It has a function with the same name
declare PKG_SPECIFIC_OPERATIONS="virtualbox clamav lightdm-slick-greeter lightdm-gtk-greeter"

# ---------------------------- Packages To Install --------------------------- #

declare CORE_PACKAGES="base linux linux-firmware"

#Warning: This variable is also modified from the pkg_specific_operations function!
declare PACKAGES="os-prober lvm2 sudo base-devel screen git python python-pip cpupower thermald dhcpcd dhclient flatpak parted htop lshw man-db man-pages texinfo mc net-tools network-manager-applet networkmanager nm-connection-editor ntfs-3g pacman-contrib unrar unzip p7zip usbutils wget xdg-user-dirs firefox deluge gimp inkscape keepassxc libreoffice-fresh vlc cups"

#All additional packages will be asked to user.
#They will be added to the original set if accepted.
declare ADDITIONAL_PACKAGES="virtualbox clamav"

declare BOOTLOADER_PACKAGES="grub intel-ucode amd-ucode"

declare DE_PACKAGES="xorg xorg-server xfce4 xfce4-goodies"
declare DE_DEPENDENT_PACKAGES="xsane system-config-printer gparted deluge-gtk foliate eom evolution evolution-on file-roller atril gvfs gvfs-mtp gufw pavucontrol pulseaudio seahorse"

declare AUR_PACKAGES="cpupower-gui-git nano-syntax-highlighting"
declare ADDITIONAL_AUR_PACKAGES="ttf-ms-fonts"

declare DISPLAY_MANAGER="lightdm"

declare GREETER="lightdm-gtk-greeter"
declare GREETER_AUR="lightdm-slick-greeter"
declare SELECTED_GREETER=""

declare VIDEO_DRIVER="xf86-video-intel xf86-video-nouveau xf86-video-ati xf86-video-amdgpu nvidia"
declare VIDEO_DRIVER_AUR="nvidia-390xx"
declare SELECTED_VIDEO_DRIVER=""

#Warning: This variable is also modified from the pkg_specific_operations function!
#Services to enable
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
#declare ORANGE='\033[0;33m'
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
    
    rm -f "/tmp/$PROGRAM_NAME.lock"
    
    #Umount_
    
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

    echo
    printf "${LIGHT_CYAN}%s${NOCOLOUR}" "$1"
}


function prompt_different () {

    printf "${LIGHT_GREEN}%s${NOCOLOUR}" "$1"
}

function prompt_partition () {

    echo
    printf "${LIGHT_CYAN}Please enter the${LIGHT_RED} PATH ${LIGHT_CYAN}for${LIGHT_RED} %s ${LIGHT_CYAN}partition:${NOCOLOUR}" "$1"
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
    partprobe &> /dev/null
}


function Exit_ () {

    rm -f "/tmp/$PROGRAM_NAME.lock"

    #Umount_

    exit "$1"
}


function failure () {

    prompt_warning "$1"
    prompt_warning "Exiting..."
    Exit_ 1
}


function yes_no () {

    read -e -r -p " " ANSWER

    while ! output=$([ "$ANSWER" == "y" ] || [ "$ANSWER" == "Y" ] || [ "$ANSWER" == "n" ] || [ "$ANSWER" == "N" ]); do

        echo
        prompt_warning "Wrong answer!"
        printf "Please try again:"
        read -e -r -p " " ANSWER
    done

    if [ "$ANSWER" == "Y" ]; then ANSWER="y"; fi
    if [ "$ANSWER" == "N" ]; then ANSWER="n"; fi
}

# ------------------------------ Check Functions ----------------------------- #
#Principle:
#If no arguments passed, read it from the user and check the input.
#If user entered wrongly loop until the correct answer has got.
#Otherwise, check the given argument and if false return a value

function disk_check () {

    declare input=""
    declare is_argument=""
    
    if [ -n "$1" ]; then
    
        is_argument="true"
        input="$1"
    else
        
        is_argument="false"
        read -e -r -p " " input
    fi
    

    #Use awk to remove unnecessary spaces
    while ! output=$(lsblk -o type,path | awk '{print $1,$2}'| grep -x "disk $input"); do
    
        if [ "$is_argument" == "false" ]; then
            
            echo
            prompt_warning "The disk '$input' couldn't found."
            printf "${LIGHT_CYAN}Please give a ${LIGHT_RED}PATH${LIGHT_CYAN}: ${NOCOLOUR}"
            read -e -r -p " " input
        else
        
            return 12
        fi
    done

   DISK_CHECK="$input"
}


function partition_check () {

    declare input=""
    declare is_argument=""
    
    if [ -n "$1" ]; then
    
        is_argument="true"
        input="$1"
    else
        
        is_argument="false"
        read -e -r -p " " input
    fi

    #Use awk to remove unnecessary spaces
    while ! output=$( { lsblk -o type,path "$DISK" | awk '{print $1,$2}' | grep -v "disk" | grep -w "$input"; } && [ -n "$input" ] ); do
    
        if [ "$is_argument" == "false" ]; then
        
            echo
            prompt_warning "Partition '$input' couldn't found."
            printf "${LIGHT_CYAN}Please give a ${LIGHT_RED}PATH${LIGHT_CYAN}: ${NOCOLOUR}"
            read -e -r -p " " input
        else
        
            return 13
        fi
    done

   PART_CHECK="$input"
}


function number_check () {

    declare max_=0
    
    #max_ cannot be zero nor char
    if output=$([[ ! $1 =~ ^[0-9]+$ ]] || (( $1 == 0 )) ); then
    
        failure "number_check: ERROR! Max cannot be zero nor char. (Received value: $1)"
    else
    
        max_=$1
    fi
    
    
    declare is_argument=""
    if [ -n "$2" ]; then
    
        is_argument="true"
        NUMBER_CHECK="$2"
    else
        
        is_argument="false"
        read -e -r -p " " NUMBER_CHECK
    fi
    
    while output=$( [[ ! $NUMBER_CHECK =~ ^[0-9]+$ ]] || (( NUMBER_CHECK > max_ )) || (( NUMBER_CHECK == 0 )) ); do
    
        if [ "$is_argument" == "false" ]; then
            
            echo
            prompt_warning "Wrong number!"
            prompt_question "Please re-enter:"
            read -e -r -p " " NUMBER_CHECK
        else
        
            return 14
        fi
    done
}

#This is similar to "cat -n ... | less" command
function list {

    clear

    declare list=""
    declare message=""
    
    list="$1"
    message="$2"
    
    {
        declare -i n=0
    
        printf "$message\n"
        echo
        prompt_different "PRESS (Q) TO QUIT LISTING!"
        echo
        printf "${LIGHT_RED}(/: search forward, ?: search backward, h: Help, Navigation: ↑↓, pg-up, pg-down)\n\n"
        
        for i in $list; do
    
            n+=1
            printf "${LIGHT_CYAN}%s ${NOCOLOUR}" "$n"
            printf "${PURPLE}%s${NOCOLOUR}\n" "$i"
        done
        echo
        prompt_different "PRESS (Q) TO QUIT LISTING!"
        echo
    } | less --raw-control-chars
}

function print_packages () {

    clear
    
    echo
    printf "${LIGHT_GREEN}For printer drivers follow this link: ${PURPLE}https://wiki.archlinux.org/title/CUPS/Printer-specific_problems#Epson"
    echo
    
    prompt_warning "Current selected packages are:"
    echo
    
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


#Takes an additional package set as an argument
#and asks each of them to include it in the original set or not
function pkg_select () {

    declare selection_=""
    print_packages

    for i in $1; do
    
        printf "${LIGHT_GREEN}Do you want to install${LIGHT_RED} %s${LIGHT_GREEN}? (y/n)${LIGHT_GREEN}: ${NOCOLOUR}" "$i"
        yes_no
        
        #Delete the previous line
        printf "\033[1A\033[2K\r"
        
        if [ "$ANSWER" == "y" ]; then
        
            selection_+=" $i"
        fi
    done
    
    PKG_SELECT="$selection_"
}


#Search for a package and add it to the PKG_FIND if exist
#--quiet: Check only one package and return accordingly
function pkg_find () {

    declare is_quiet=""
    declare search=("")

    if [ "$1" == "--quiet" ]; then

        is_quiet="true"
        search=("$2")
    else

        is_quiet="false"
        search=("$@")
    fi

    #Check if the given package is alredy found
    for i in $PKG_FIND; do
    
        for j in "${search[@]}"; do
        
            if [ "$j" == "$i" ]; then

                if [ "$is_quiet" == "false" ]; then

                    search=( "${search[@]/$i}" ) #Omit the founded package
                else

                    return 0
                fi
            fi
        done
    done
    
    #Make values unique
    #https://stackoverflow.com/questions/13648410/how-can-i-get-unique-values-from-an-array-in-bash
    #https://github.com/koalaman/shellcheck/wiki/SC2207
    IFS=" " read -r -a search <<< "$(tr ' ' '\n' <<< "${search[@]}" | sort -u | tr '\n' ' ')"
    
    #Search for the given package
    if [ "${#search[@]}" != "0" ]; then
    
        for i in $CORE_PACKAGES $PACKAGES $BOOTLOADER_PACKAGES $DISPLAY_MANAGER $DE_PACKAGES $DE_DEPENDENT_PACKAGES $AUR_PACKAGES $SELECTED_GREETER $SELECTED_VIDEO_DRIVER; do
        
            for j in "${search[@]}"; do
            
                if [ "$i" == "$j" ]; then
                
                    PKG_FIND+=" $j" #Add to the PKG_FIND
                    
                    if [ "$is_quiet" == "false" ]; then

                        search=( "${search[@]/$i}" ) #Omit the founded package, thus optimize the search.
                    else

                        return 0
                    fi
                fi
            done
        done
    fi

    if [ "$is_quiet" == "true" ]; then

        return 17
    fi
}

#A space must be put before adding it to the package set
#i.e. syntax should be: foo+=" bar"
function pkg_specific_operations () {

    pkg_find "$@"
    
    for i in $PKG_FIND; do
    
        for j in "$@"; do
        
            if [ "$j" == "$i" ]; then
            
                case $j in
                
                    #https://wiki.archlinux.org/title/VirtualBox#Installation_steps_for_Arch_Linux_hosts
                    "virtualbox")
                    
                        declare is_default_kernel=""
                        declare is_lts=""
                        
                        #Find which kernel is in use
                        pkg_find "linux" "linux-lts"
                        for it in $PKG_FIND; do
                        
                            if [ "$it" == "linux" ]; then
                            
                                is_default_kernel="true"
                                break
                            elif [ "$it" == "linux-lts" ]; then
                            
                                is_lts="true"
                                break
                            fi
                        done
                        
                        
                        #Add the needed packages to queue
                        if [ "$is_default_kernel" == "true" ]; then
                        
                            PACKAGES+=" virtualbox-host-modules-arch"
                        else
                        
                            PACKAGES+=" virtualbox-host-dkms"
                        fi
                        
                        
                        if [ "$is_lts" == "true" ]; then
                        
                            PACKAGES+=" linux-lts-headers"
                        fi
                        
                        #Warning! If you are using a custom kernel, find & install appropriate headers.
                        #They are not installed by default.
                    ;;
                    
                    "clamav")
                    
                        SERVICES+=" clamav-freshclam"
                    ;;
                    
                    "lightdm-slick-greeter")
                    
                        AUR_PACKAGES+=" lightdm-settings"
                    ;;
                    
                    "lightdm-gtk-greeter")
                    
                        PACKAGES+=" lightdm-gtk-greeter-settings"
                    ;;
                esac
            fi
        done
    done
}

function select_one () {

    declare message=""
    declare official_pkgs=""
    declare aur_pkgs=""
    
    message="$1"
    official_pkgs="$2"
    aur_pkgs="$3"

    prompt_different "$message"
    echo
    echo
    
    declare -i max=0
    for i in $official_pkgs; do
    
        max+=1
        printf "${PURPLE}%s (${LIGHT_CYAN}%s${PURPLE}) ${NOCOLOUR}" "$i" "$max"
    done
    
    declare -i aur_part=0
    aur_part+=$max+1
    for i in $aur_pkgs; do
    
        max+=1
        printf "${PURPLE}%s (${LIGHT_CYAN}%s${PURPLE}) ${NOCOLOUR}" "$i" "$max"
    done
    
    #Selection
    echo
    echo
    prompt_question "Please select one:"
    number_check "$max"
    
    #Include it in the installation
    declare -i current=0
    for i in $official_pkgs $aur_pkgs; do
    
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


function post-install () {

    #Make a github directory and clone yay (will be called in user's terminal)
    function clone_yay () {

        #Generating home directories
        prompt_info "Generating $USER_NAME's home directories..."
        xdg-user-dirs-update

        check_connection

        if ! [ -d "/home/$USER_NAME/Git-Hub/yay" ]; then

            prompt_info "Cloning yay..."
            cd "/home/$USER_NAME" || failure "Cannot change directory to /home/$USER_NAME"
            
            mkdir -p Git-Hub || failure "/home/$USER_NAME/Git-Hub directory couldn't made."
            cd Git-Hub || failure "Cannot change directory to /home/$USER_NAME/Git-Hub"
            
            git clone https://aur.archlinux.org/yay.git || failure "Cannot clone yay."
        fi
    }

    #Generating home directories
    prompt_info "Generating 'root' home directories..."
    xdg-user-dirs-update
    
    #Install go for yay
    prompt_info "Installing go for aur helper..."
    pacman -S --noconfirm go
    
    #Export variables to use it in the user's shell
    export USER_NAME="$USER_NAME"
    
    #Export functions to call it in the user's shell
    export -f clone_yay
    export -f check_connection

    #Clone yay
    su "$USER_NAME" /bin/bash -c clone_yay || Exit_ $?

    #Install yay
    prompt_info "Installing yay..."
    cd "/home/$USER_NAME/Git-Hub/yay" || failure "Cannot change directory to /home/$USER_NAME/Git-Hub/yay"
    sudo -u "$USER_NAME" makepkg -si --noconfirm || failure "Error Cannot install yay!"

    #Download aur pkgbuilds
    prompt_info "Downloading aur pkgbuilds..."
    mkdir -p "/home/$USER_NAME/.cache/yay" || failure "Cannot make /home/$USER_NAME/.cache/yay directory!"
    cd "/home/$USER_NAME/.cache/yay" || failure "Cannot change directory to /home/$USER_NAME/.cache/yay"
    yay --getpkgbuild $AUR_PACKAGES || failure "Cannot download pkgbuilds!"

    #Arrange permissions
    chown -R "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.cache/"

    #Install aur packages
    prompt_info "Installing aur packages..."
    cd "/home/$USER_NAME/.cache/yay" || failure "Cannot change directory to /home/$USER_NAME/.cache/yay"
    for i in *; do

        cd "$i"
        sudo -u "$USER_NAME" makepkg -si --noconfirm
        cd ..
    done
    
    # ------------------------------- Login Manager ------------------------------ #
    #Check if /etc/lightdm.conf exists
    if [ -f "/etc/lightdm/lightdm.conf" ]; then
    
        if pacman -Q "$SELECTED_GREETER"; then
        
            declare lightdm_conf=""
            lightdm_conf=$(sed "s/#greeter-session=example-gtk-gnome/greeter-session=$SELECTED_GREETER/g" /etc/lightdm/lightdm.conf)
            
            sleep 1s
            
            prompt_info "Activating $SELECTED_GREETER..."
            if [ -n "$lightdm_conf" ]; then
            
                prompt_info "Backing up /etc/lightdm/lightdm.conf to /etc/lightdm/lightdm.conf.backup..."
                mv /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.backup
                echo "$lightdm_conf" > /etc/lightdm/lightdm.conf
            else
            
                prompt_warning "Cannot modify /etc/lightdm/lightdm.conf file."
                prompt_warning "You have to modify it manually."
                printf "${LIGHT_RED}greeter-session=example-gtk-gnome ${LIGHT_GREEN}should be equal to ${LIGHT_RED}greeter_session=$SELECTED_GREETER ${LIGHT_GREEN}-which is under the [Seat:*] section-${NOCOLOUR}"
                
                prompt_warning "Press enter to continue..."
                read -e -r -p " " tmp_key
            fi
        else
        
            prompt_warning "Warning! $SELECTED_GREETER is not installed!"
            prompt_warning "Skipping activation."
            prompt_warning "You have to modify /etc/lightdm/lightdm.conf file manually after installing it."
            printf "${LIGHT_RED}greeter-session=example-gtk-gnome ${LIGHT_GREEN}should be equal to ${LIGHT_RED}greeter_session=$SELECTED_GREETER ${LIGHT_GREEN}-which is under the [Seat:*] section-${NOCOLOUR}"
            
            prompt_warning "Press enter to continue..."
            read -e -r -p " " tmp_key
        fi
        
        printf "${YELLOW}For troubleshooting about lightdm, follow this link: ${PURPLE}https://wiki.archlinux.org/title/LightDM#Troubleshooting${NOCOLOUR}\n\n"
        for i in {10..0}; do

            printf "${LIGHT_GREEN}Continuing in ${LIGHT_CYAN}%s${NOCOLOUR}\033[0K\r" "$i"
            sleep 1s
        done
    fi

    #Enabling services
    prompt_info "Enabling services..."
    for i in $SERVICES; do
        
        systemctl enable "$i" || { prompt_warning "Cannot enable $i service!"; echo ""; echo "$i" >> "$HOME/disabled_services.txt"; prompt_warning "Service added to $HOME/disabled_services.txt, Please enable it manually."; }
    done

    #Activate time synchronization
    prompt_info "Activating time synchronization..."
    timedatectl set-ntp true

    prompt_different "AUR configuration complete!"
}



# ---------------------------------------------------------------------------- #
#                                     MAIN                                     #
# ---------------------------------------------------------------------------- #

#Lock file
if [ -f "/tmp/$PROGRAM_NAME.lock" ]; then

    prompt_warning "Another instance is already running!"
    prompt_warning "If you think this is a mistake, please delete /tmp/$PROGRAM_NAME.lock"
    prompt_warning "Exiting..."
    exit 155
else

    touch "/tmp/$PROGRAM_NAME.lock"
fi

#ASCII art
#http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=Arch%20Setup
clear
echo
echo
echo
printf "${LIGHT_CYAN}
               █████╗ ██████╗  ██████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ 
              ██╔══██╗██╔══██╗██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
              ███████║██████╔╝██║     ███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝
              ██╔══██║██╔══██╗██║     ██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
              ██║  ██║██║  ██║╚██████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     
              ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
${NOCOLOUR}"
#http://patorjk.com/software/taag/#p=display&f=Kban&t=by%20The-Plottwist
printf "${LIGHT_RED}
'||                  |''||''| '||              ' '||''|.  '||            .     .                ||           .  
 || ...  .... ...       ||     || ..     ....     ||   ||  ||    ...   .||.  .||.  ... ... ... ...   ....  .||. 
 ||'  ||  '|.  |        ||     ||' ||  .|...||    ||...|'  ||  .|  '|.  ||    ||    ||  ||  |   ||  ||. '   ||  
 ||    |   '|.|         ||     ||  ||  ||         ||       ||  ||   ||  ||    ||     ||| |||    ||  . '|..  ||  
 '|...'     '|         .||.   .||. ||.  '|...'   .||.     .||.  '|..|'  '|.'  '|.'    |   |    .||. |'..|'  '|.'
         .. |                                                                                                   
          ''                                                                                                    
${NOCOLOUR}"

#Disclaimer
prompt_different "This script is for installing archlinux on an empty (or semi-empty) disk."
echo

prompt_different "You can modify this script to your needs, otherwise XFCE will be installed with a default package set."
echo
echo

printf "${LIGHT_BLUE}If you encounter a problem or want to stop the installation process, please press ${LIGHT_CYAN}Ctrl-C${LIGHT_BLUE} to quit.${NOCOLOUR}\n"
printf "${LIGHT_BLUE}Use ${LIGHT_CYAN}Ctrl-Z${LIGHT_BLUE} in dire situations and reboot your system afterwards as it doesn't actually stop the script.${NOCOLOUR}\n"
echo

prompt_warning "This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details."
echo

#Check the internet connection before attempting anything
check_connection

#Keyboard layout
declare l_layouts=""
declare iso=""
declare iso_max=""

while true; do

    prompt_question "Please enter an ISO code to list the available keyboard layouts (ex: fr, de, au)"
    prompt_question "(You can also type 'd' to use the default [US] layout):"
    read -e -r -p " " iso

    while true; do
    
        case $iso in
        
            "D" | "d")
            
                KEY_LAYOUT="us"
                break
            ;;
        esac
        
        l_layouts=$(find /usr/share/kbd/keymaps -type f -name "*.map.gz" -printf "%f\n" | sed "s/.map.gz//g" | grep -i "$iso")
        
        if [ -n "$l_layouts" ]; then
            
            iso_max=$(echo "$l_layouts" | cat -n | tail -1 | awk '{print $1}')
            
            list "$l_layouts" "${LIGHT_GREEN}- Please find your layout in the list -\n${LIGHT_RED}- There may be irrelevent layouts -${NOCOLOUR}"
            
            prompt_question "Please specify the number of your layout or type an ISO code to re-list:"
            read -e -r -p " " iso
            
            if number_check "$iso_max" "$iso"; then
            
                KEY_LAYOUT=$(echo "$l_layouts" | head -"$iso" | tail -1)
                break
            fi
        else
        
            echo
            prompt_warning "No layouts found."
            prompt_question "Please enter another ISO or type 'd' or 's':"
            read -e -r -p " " iso
        fi
    done
    loadkeys "$KEY_LAYOUT"
    
    clear
    
    prompt_question "Do you want to test your layout? (y/n):"
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        declare tmp_file=""
        tmp_file="$(mktemp /tmp/Layout_test.XXXXXXXXXX)"
        
        {
            echo ""
            echo "# This is a temporary file for testing your layout."
            echo "# Some characters may not render, it is fine. Don't worry."
            echo "# Your layout is '$KEY_LAYOUT'"
            echo
            echo "# You can save with Ctrl-S,"
            echo "# quit with Ctrl-X,"
            echo "# and open help with Ctrl-G."
        } > "$tmp_file"
        
        nano "$tmp_file"
        clear
    fi
    
    printf "${LIGHT_CYAN}Do you want to change ${LIGHT_RED}$KEY_LAYOUT${LIGHT_CYAN} layout? (y/n):${NOCOLOUR}"
    yes_no
    
    if [ "$ANSWER" == "n" ]; then
    
        break
    fi
done

#Device name
echo
printf "${LIGHT_CYAN}Please give your device a ${LIGHT_RED}HOST${LIGHT_CYAN} name:${NOCOLOUR}"
read -e -r -p " " DEVICE

VOLGROUP="$DEVICE"VolGroup

MOUNT_PATH="$HOME/INSTALL/$DEVICE"
mkdir -p "$MOUNT_PATH"


#User name
prompt_question "Please enter a user name:"
read -e -r -p " " USER_NAME
while ! { useradd "$USER_NAME" &> /dev/null; }; do

    echo
    prompt_warning "Invalid user name!"
    prompt_question "Please re-enter:"
    read -e -r -p " " USER_NAME
done
userdel "$USER_NAME"

#User pass
while true; do

    declare check=""

    printf "${LIGHT_CYAN}Please enter a password for user ${LIGHT_RED}$USER_NAME${LIGHT_CYAN}:${NOCOLOUR}"
    read -s -e -r -p " " USER_PASS
    
    prompt_question "Please re-enter:"
    read -s -e -r -p " " check
    
    if [ "$USER_PASS" == "$check" ]; then
    
        break
    else
    
        echo
        echo
        prompt_warning "Passwords don't match!"
    fi
done

echo
echo

#Root pass
while true; do

    check=""

    printf "${LIGHT_CYAN}Please enter a password for ${LIGHT_RED}root${LIGHT_CYAN}:${NOCOLOUR}"
    read -s -e -r -p " " ROOT_PASS
    
    prompt_question "Please re-enter:"
    read -s -e -r -p " " check
    
    if [ "$ROOT_PASS" == "$check" ]; then
    
        break
    else
    
        echo
	echo
        prompt_warning "Passwords don't match!"
    fi
done

clear

#Timezone
declare l_timezones=""
declare max=""
declare input=""

l_timezones="$(timedatectl list-timezones)"
max=$(echo "$l_timezones" | cat -n | tail -1 | awk '{print $1}')
input="r"

while true; do

    if [ "$input" == "r" ]; then
    
        list "$l_timezones" "${LIGHT_GREEN}- Please find your timezone in the list -\n${YELLOW}If you're dual booting with Windows, follow this link: ${PURPLE}https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows${NOCOLOUR}"
    else
    
        if number_check "$max" "$input"; then
        
            break
        else
        
            prompt_warning "Wrong Number!"
        fi
    fi
    
    prompt_question "Please specify the number of your timezone - or type 'r' to re-list -:"
    read -e -r -p " " input
done

TIMEZONE=$(echo "$l_timezones" | head -"$NUMBER_CHECK" | tail -1)

echo
printf "${LIGHT_GREEN}Your timezone is: ${LIGHT_CYAN}%s${NOCOLOUR}" "$TIMEZONE"

sleep 2s

#Get Disk
clear
lsblk -o +path,partlabel | head -1
lsblk -o +path,partlabel | grep "disk"
echo
printf "${LIGHT_CYAN}Please enter the${LIGHT_RED} PATH ${LIGHT_CYAN}for the disk you want to operate:${NOCOLOUR}"
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

#Get info
declare PARTED_INFO=""
PARTED_INFO="$(parted "$DISK" --script "u mib" \ "print")"

#Get disk size in MiB and subtract the extension
DISK_SIZE_MIB=$(echo "$PARTED_INFO" | grep "Disk $DISK:" | awk '{print $3}' | sed s/[A-Za-z]//g)

#Get Partition Table
PARTITION_TABLE=$(echo "$PARTED_INFO" | grep "Partition Table:" | awk '{print $3}')

if output=$([ "$PARTITION_TABLE" != "msdos" ] && [ "$PARTITION_TABLE" != "gpt" ]); then

    PARTITION_TABLE="other"
fi

#Trimming
#https://wiki.archlinux.org/title/Solid_state_drive#TRIM
if echo "$PARTED_INFO" | head -1 | grep -w -q SSD; then

    declare TRIM_INFO=""
    declare DISC_GRAN=""
    declare DISC_MAX=""
    
    TRIM_INFO="$(lsblk "$DISK" -o type,DISC-GRAN,DISC-MAX | grep -w disk)"
    DISC_GRAN=$(echo "$TRIM_INFO" | awk '{print $2}')
    DISC_MAX=$(echo "$TRIM_INFO" | awk '{print $3}')
    
    #Check if it supports trimming
    if output=$([ "$DISC_GRAN" != "0B" ] && [ "$DISC_MAX" != "0B" ]); then
    
        SERVICES+=" fstrim.timer"
    fi
fi

#Swap size
declare -i swap_size=0
swap_size=$(free --giga | grep Mem: | awk '{print $2}')

if (( swap_size <= 2 )); then

    swap_size="$swap_size*3"
elif (( swap_size <= 8 )); then

    swap_size="$swap_size*2"
elif (( swap_size > 8 )); then

    swap_size=$((( swap_size/2+swap_size )))
fi
swap_size="$swap_size*1024" #Convert to MiB

# ------------------------------- Partitioning ------------------------------- #
#In the below link, you can find the answer for the question of - Why first partition generally starts from sector 2048 (1mib)? -
#https://www.thomas-krenn.com/en/wiki/Partition_Alignment_detailed_explanation

if [ "$ENABLE_AUTO_PARTITIONING" == "true" ]; then

    printf "${LIGHT_CYAN}Do you want to use auto partitioning? ${LIGHT_RED}-Everything will be ERASED-${LIGHT_CYAN} (y/n): ${NOCOLOUR}"
    yes_no
fi

if output=$([ "$ENABLE_AUTO_PARTITIONING" == "true" ] && [ "$ANSWER" == "y" ] ); then


    #GPT is required for disks that are larger than 2TB
    if (( ! DISK_SIZE_MIB < 1907347 )); then

        PARTITION_TABLE="gpt"
    fi

    #Sizing                                             #Schemes used

    #BIOS Grub - 1mib
    #EFI System Partition [ESP] - 512mib                https://wiki.archlinux.org/title/EFI_system_partition#Create_the_partition
    #Boot - 500mib
    #Swap - differs                                     https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/installation_guide/s2-diskpartrecommend-x86
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
    NEEDED_SIZE+=$swap_size #SWAP
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
        prompt_question "Do you still want to use MBR? (y/n):"
        yes_no
        if [ "$ANSWER" == "y" ]; then
        
            PARTITION_TABLE="msdos" #Parted refers msdos as mbr
        else
        
            PARTITION_TABLE="gpt"
        fi
    fi


    prompt_question "Do you want an encrypted system partition? (y/n):"
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        IS_ENCRYPT="true"
    else
    
        IS_ENCRYPT="false"

        prompt_question "Do you want seperate home and system partitions? (y/n):"
        yes_no
        if [ "$ANSWER" == "y" ]; then
        
            IS_SEPERATE="true"
        else
        
            IS_SEPERATE="false"
        fi
    fi


    # ---------------------------------------------------------------------------- #
    #                        Countdown before hard disk wipe                       #
    # ---------------------------------------------------------------------------- #
    for i in {10..0}; do

        clear
        printf "${LIGHT_RED}DANGER! your hard disk will be WIPED in: ${LIGHT_CYAN}%s${NOCOLOUR}" "$i"
        echo
        echo
        printf "${LIGHT_GREEN}- You can quit with Ctrl-C -${NOCOLOUR}"
        sleep 1s
    done

    #Partition start, ends
    declare -i swap_e=0
    declare -i system_s=0
    declare -i system_e=0
    declare -i home_s=0
    
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
    
        if [ "$IS_UEFI" == "true" ]; then
        
            if [ "$IS_SEPERATE" == "true" ]; then #Encrypt false, UEFI=true, is seperate=true
                
                swap_e=$swap_size+1015
                system_s=$swap_e+1
                system_e=$system_s+32768
                home_s=$system_e+1
                
                parted "$DISK" --script "mktable gpt" \
                                        "mkpart \"EFI System Partition\" 1mib 513mib" \
                                        "mkpart BOOT 514mib 1014mib" \
                                        "mkpart SWAP 1015mib \"$swap_e\"mib"
                                        "mkpart SYSTEM \"$system_s\"mib \"$system_e\"mib" \
                                        "mkpart HOME \"$home_s\"mib -1"

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
            
                swap_e=$swap_size+1015
                system_s=$swap_e+1
            
                parted "$DISK" --script "mktable gpt" \
                                        "mkpart \"EFI System Partition\" 1mib 513mib" \
                                        "mkpart BOOT 514mib 1014mib" \
                                        "mkpart SWAP 1015mib \"$swap_e\"mib" \
                                        "mkpart SYSTEM \"$system_s\"mib -1"

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
                
                    swap_e=$swap_size+504
                    system_s=$swap_e+1
                    system_e=$system_s+32768
                    home_s=$system_e+1
                
                    parted "$DISK" --script "mktable gpt" \
                                            "mkpart GRUB 1mib 2mib" \
                                            "mkpart BOOT 3mib 503mib" \
                                            "mkpart SWAP 504mib \"$swap_e\"mib" \
                                            "mkpart SYSTEM \"$system_s\"mib \"$system_e\"mib" \
                                            "mkpart HOME \"$home_s\"mib -1"
                    
                    parted "$DISK" --script "set 1 bios_grub on"
                    
                    BOOT_PARTITION="$DISK"2
                    SWAP_PARTITION="$DISK"3
                    SYSTEM_PARTITION="$DISK"4
                    HOME_PARTITION="$DISK"5
                else #Encrypt false, UEFI=false, is seperate=true, partition table=mbr
                
                    swap_e=$swap_size+503
                    system_s=$swap_e+1
                    system_e=$system_s+32768
                    home_s=$system_e+1
                
                    parted "$DISK" --script "mktable msdos" \
                                            "mkpart primary 1mib 501mib" \
                                            "mkpart extended 502mib -1" \
                                            "mkpart logical 503mib \"$swap_e\"mib" \
                                            "mkpart logical \"$system_s\"mib \"$system_e\"mib" \
                                            "mkpart logical \"$home_s\"mib -1"
                    
                    BOOT_PARTITION="$DISK"1
                    #Warning! Logical partitions start from 5.
                    #The reason is that in MBR partition table only four primary partitions can be made, so the first four is reserved
                    SWAP_PARTITION="$DISK"5
                    SYSTEM_PARTITION="$DISK"6
                    HOME_PARTITION="$DISK"7
                fi
            else
            
                if [ "$PARTITION_TABLE" == "gpt" ]; then #Encrypt false, UEFI=false, is seperate=false, partition table=gpt
                
                    swap_e=$swap_size+504
                    system_s=$swap_e+1
                
                    parted "$DISK" --script "mktable gpt" \
                                            "mkpart GRUB 1mib 2mib" \
                                            "mkpart BOOT 3mib 503mib" \
                                            "mkpart SWAP 504mib \"$swap_e\"mib" \
                                            "mkpart SYSTEM \"$system_s\"mib -1"
                                        
                    parted "$DISK" --script "set 1 bios_grub on"
                    
                    BOOT_PARTITION="$DISK"2
                    SWAP_PARTITION="$DISK"3
                    SYSTEM_PARTITION="$DISK"4
                else #Encrypt false, UEFI=false, is seperate=false, partition table=mbr
                
                    swap_e=$swap_size+503
                    system_s=$swap_e+1
                
                    parted "$DISK" --script "mktable msdos" \
                                            "mkpart primary 1mib 501mib" \
                                            "mkpart extended 502mib -1" \
                                            "mkpart logical 503mib \"$swap_e\"mib" \
                                            "mkpart logical \"$system_s\"mib -1"
                    
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
        printf "${YELLOW}For manual partitioning, see: ${PURPLE}https://github.com/The-Plottwist/Arch-setup/blob/main/Partitioning-manual.md${NOCOLOUR}\n\n"
        failure "Please use auto partitioning or format it with a correct table (MBR or GPT)."
    fi
    
    #Inform the user about needed partitions
    clear
    printf "${YELLOW}For manual partitioning, see: ${PURPLE}https://github.com/The-Plottwist/Arch-setup/blob/main/Partitioning-manual.md${NOCOLOUR}\n\n"
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
    declare luks=""
    luks=$(lsblk "$DISK" -o path,fstype | grep "crypto_LUKS" | awk '{print $1}')

    if [ -n "$luks" ]; then

        prompt_warning "In this option, encrypted partitions will not be handled automatically."
        printf "${YELLOW}You need to follow one of the guides in: ${PURPLE}https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#Overview${NOCOLOUR}"
        echo
        prompt_info "LUKS partitions found!"
        printf "\033[1A"
        prompt_different "$luks"
        echo
        echo
    
        declare -i current_=0
        for i in $luks; do
    
            prompt_question "Do you want to open $i (y/n):"
            yes_no
    
            if [ "$ANSWER" == "y" ]; then
    
                current_+=1
    
                prompt_info "Opening $i..."
                cryptsetup open "$i" LUKS$current_ || failure "Error! Cannot open $i, try rebooting."
            fi

            sleep 1s
        done
    fi

    #Print the disk
    echo
    lsblk "$DISK" -o +path,partlabel

    #BIOS GRUB partition
    if output=$([ "$PARTITION_TABLE" == "gpt" ] && [ "$IS_UEFI" == "false" ]); then
        
        declare p_bg=""

        prompt_partition "BIOS Grub"
        partition_check
        p_bg=$(echo "$PART_CHECK" | sed "s/[A-Za-z]//g" | sed "s/\///g")

        parted "$DISK" --script "set $p_bg bios_grub on"
    fi

    #Get ESP
    if [ "$IS_UEFI" == "true" ]; then
    
        IS_ESP_FORMAT="false"
    
        #Make is_esp directory and don't prompt for error if exist
        mkdir -p /mnt/is_esp
    
        while true; do
            
            prompt_partition "EFI System"
            partition_check
            mount "$PART_CHECK" /mnt/is_esp
            
            #Look for EFI directory. If it exists then it is an ESP.
            if [ -d "/mnt/is_esp/EFI" ]; then
            
                ESP="$PART_CHECK"
                umount /mnt/is_esp
                break
            else
            
                prompt_warning "Couldn't found EFI directory. Are you sure this is the right partition? (y/n):"
                yes_no
                
                if [ "$ANSWER" == "y" ]; then
                
                    mkdir -p /mnt/is_esp/EFI
                    umount /mnt/is_esp
                    break
                fi
                
                umount /mnt/is_esp
            fi
        done
    fi
    
    #Get Boot
    prompt_partition "BOOT"
    partition_check
    BOOT_PARTITION="$PART_CHECK"
    
    #Get Swap
    prompt_partition "SWAP"
    partition_check
    SWAP_PARTITION="$PART_CHECK"

    #Is seperate?
    echo
    prompt_different "Does home and system partitions seperate? (y/n):"
    yes_no
    if [ "$ANSWER" == "y" ]; then
    
        IS_SEPERATE="true"
    
        #Get System
        prompt_partition "SYSTEM"
        partition_check
        SYSTEM_PARTITION="$PART_CHECK"
    
        #Home
        prompt_partition "HOME"
        partition_check
        HOME_PARTITION="$PART_CHECK"
    else

        IS_SEPERATE="false"
    
        #Get Systen
        prompt_partition "SYSTEM"
        partition_check
        SYSTEM_PARTITION="$PART_CHECK"
    fi
fi

#Wait before using parted again in case the disk is old
sleep 3s

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
    lvcreate -L "$swap_size" "$VOLGROUP" -n swap
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
select_one "Greeter packages are:" "$GREETER" "$GREETER_AUR"
SELECTED_GREETER="$SELECTION"

print_packages

#Video driver selection
prompt_different "Your graphics card model is:"
lspci -v | grep -A1 -e VGA -e 3D
echo
printf "${YELLOW}You can look here for additional infromation: ${PURPLE}https://wiki.archlinux.org/title/xorg#Driver_installation${NOCOLOUR}"
echo

select_one "Available driver packages are:" "$VIDEO_DRIVER" "$VIDEO_DRIVER_AUR"
SELECTED_VIDEO_DRIVER="$SELECTION"

pkg_specific_operations $PKG_SPECIFIC_OPERATIONS

print_packages

#Sort mirrorslist
check_connection
printf "${LIGHT_GREEN}Do you want to sort the mirror list to make the downloads faster?${LIGHT_RED} - It will persist in the system but will take a while - ${LIGHT_GREEN}(y/n): ${NOCOLOUR}"
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

#Nano is a dependency for the script
pacstrap "$MOUNT_PATH" nano $CORE_PACKAGES $PACKAGES $BOOTLOADER_PACKAGES $DISPLAY_MANAGER $DE_PACKAGES $DE_DEPENDENT_PACKAGES

#Generate fstab
prompt_info "Generating fstab..."
genfstab -U "$MOUNT_PATH" >> "$MOUNT_PATH/etc/fstab"


# ---------------------------------------------------------------------------- #
#                                     Setup                                    #
# ---------------------------------------------------------------------------- #
function setup () {

    #Timezone
    prompt_info "Setting timezone..."
    ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    
    #Locales
    declare locale=""
    locale=$(sed "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g" /etc/locale.gen)
    
    if [ -n "$locale" ]; then
    
        prompt_info "Backing up /etc/locale.gen to /etc/locale.gen.bak..."
        mv /etc/locale.gen /etc/locale.gen.bak
        
        prompt_info "Configuring /etc/locale.gen..."
        echo "$locale" > /etc/locale.gen
    else
    
        prompt_warning "Cannot modify /etc/locale.gen!"
        prompt_warning "You have to modify it manually."
        echo
        
        prompt_different "Just uncomment en_US.UTF-8 UTF-8 and YOUR LOCALE in the file is going to open."
        echo
        prompt_question "(Ctrl-S: Save, Ctrl-X: Quit, Ctrl-G: Help)"
        echo
        prompt_warning "Press enter to continue..."
        read -e -r -p " " tmp_key
        
        nano /etc/locale.gen
        clear
    fi
    prompt_info "Generating locale(s)..."
    locale-gen
    
    #Locale.conf
    prompt_info "Generating /etc/locale.conf..."
    printf "LANG=en_US.UTF-8" > /etc/locale.conf
    
    #Keymap
    prompt_info "Generating /etc/vconsole.conf..."
    echo "KEYMAP=$KEY_LAYOUT" > /etc/vconsole.conf

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
    
    declare mkinitcpio=""
    
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        mkinitcpio=$(sed "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems resume fsck)/g" /etc/mkinitcpio.conf)
    else
    
        mkinitcpio=$(sed "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck)/g" /etc/mkinitcpio.conf)
    fi
    
    #Wait for read/write operations
    sleep 1s
    
    if [ -n "$mkinitcpio" ]; then
    
        prompt_info "Backing up /etc/mkinitcpio.conf to /etc/mkinitcpio.conf.bak..."
        mv /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
        
        prompt_info "Configuring /etc/mkinitcpio.conf..."
        echo "$mkinitcpio" > /etc/mkinitcpio.conf
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
        printf "${LIGHT_GREEN}Just add '#' to the begining of the first ${LIGHT_RED}'HOOKS=...' ${LIGHT_GREEN}line.${NOCOLOUR}"
        echo
        prompt_question "(Ctrl-S: Save, Ctrl-X: Quit, Ctrl-G: Help)"
        echo
        prompt_warning "Press enter to continue..."
        read -e -r -p " " tmp_key
        
        nano /etc/mkinitcpio.conf
        clear
    fi
    
    # -------------------------------- Boot Loader ------------------------------- #
    
    prompt_info "Installing grub..."
    grub-install $GRUB_ARGS
    
    #Configure grub
    declare cmdline=""
    
    if [ "$IS_ENCRYPT" == "true" ]; then
    
        declare encrypt_uuid=""
        encrypt_uuid=$(blkid "$ENCRYPT_PARTITION" | awk '{print $2}' | sed s/\"//g)
        
        cmdline=$(sed "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=$encrypt_uuid:cryptlvm root=/dev/$VOLGROUP/root resume=/dev/$VOLGROUP/swap\"|g" /etc/default/grub)
    else
        
        #For hibernation
        declare swap_uuid=""
        swap_uuid=$(blkid "$SWAP_PARTITION" | awk '{print $2}' | sed s/\"//g)
        
        cmdline=$(sed "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"resume=$swap_uuid\"|g" /etc/default/grub)
    fi
    
    #Wait for read/write operations
    sleep 1s
    
    if [ -n "$cmdline" ]; then
            
        prompt_info "Backing up /etc/default/grub to /etc/default/grub.bak..."
        mv /etc/default/grub /etc/default/grub.bak
        
        prompt_info "Configuring /etc/default/grub..."
        echo "$cmdline" > /etc/default/grub
    else
    
        prompt_warning "Cannot modify /etc/default/grub!"
        prompt_warning "You have to modify it manually."
        
        if [ "$IS_ENCRYPT" == "true" ]; then
            
            echo "GRUB_CMDLINE_LINUX=\"cryptdevice=$encrypt_uuid:cryptlvm root=/dev/$VOLGROUP/root resume=/dev/$VOLGROUP/swap\"" >> /etc/default/grub
        else
        
            echo "GRUB_CMDLINE_LINUX=\"resume=$swap_uuid\"" >> /etc/default/grub
        fi
        
        prompt_different "Needed format appended to the file.\n"
        printf "${LIGHT_GREEN}Just add '#' to the beginning of the first ${LIGHT_RED}'GRUB_CMDLINE_LINUX='${LIGHT_GREEN} line.${NOCOLOUR}"
        echo
        prompt_question "(Ctrl-S: Save, Ctrl-X: Quit, Ctrl-G: Help)"
        echo
        prompt_warning "Press enter to continue..."
        read -e -r -p " " tmp_key
        
        nano /etc/default/grub
        clear
    fi
    prompt_info "Generating grub.cfg..."
    grub-mkconfig -o /boot/grub/grub.cfg
    
    printf "${YELLOW}For troubleshooting about suspend/hibernate, follow this link: ${PURPLE}https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Troubleshooting${NOCOLOUR}\n\n"
    for i in {10..0}; do

        printf "${LIGHT_GREEN}Continuing in ${LIGHT_CYAN}%s${NOCOLOUR}\033[0K\r" "$i"
        sleep 1s
    done
    
    #Enable sudo
    prompt_info "Enabling sudo..."
    declare sudoers=""
    sudoers=$(sed "s/# %sudo/%sudo/g" /etc/sudoers)
    
    sleep 1s
    
    if [ -n "$sudoers" ]; then
        
        prompt_info "Backing up /etc/sudoers to /etc/sudoers.bak"
        mv /etc/sudoers /etc/sudoers.bak
        echo "$sudoers" > /etc/sudoers
    else
    
        prompt_warning "Cannot modify /etc/sudoers!"
        prompt_warning "You have to modify it manually."
        
        printf "${LIGHT_GREEN}Just delete the '#' ${LIGHT_RED}'# %sudo...'${LIGHT_GREEN} line.${NOCOLOUR}"
        echo
        prompt_question "(Ctrl-S: Save, Ctrl-X: Quit, Ctrl-G: Help)"
        echo
        prompt_warning "Press enter to continue..."
        read -e -r -p " " tmp_key
        
        nano /etc/sudoers
        clear
    fi
    groupadd sudo

    #User
    prompt_info "Adding user..."
    useradd -m -G sudo "$USER_NAME"
    echo "$USER_NAME:$USER_PASS" | chpasswd
    
    #Root
    prompt_info "Changing root pass..."
    echo "root:$ROOT_PASS" | chpasswd
}


#Export variables to be able to use in chroot
export USER_NAME="$USER_NAME"
export USER_PASS="$USER_PASS"
export ROOT_PASS="$ROOT_PASS"
export KEY_LAYOUT="$KEY_LAYOUT"
export TIMEZONE="$TIMEZONE"

export DEVICE="$DEVICE"
export VOLGROUP="$VOLGROUP"

export DISK="$DISK"
export IS_ENCRYPT="$IS_ENCRYPT"
export ENCRYPT_PARTITION="$ENCRYPT_PARTITION"
export SWAP_PARTITION="$SWAP_PARTITION"
export GRUB_ARGS="$GRUB_ARGS"

export NUMBER_CHECK="$NUMBER_CHECK"
export ANSWER="$ANSWER"

export YELLOW="$YELLOW"
export PURPLE="$PURPLE"
export LIGHT_RED="$LIGHT_RED"
export LIGHT_CYAN="$LIGHT_CYAN"
export LIGHT_GREEN="$LIGHT_GREEN"
export NOCOLOUR="$NOCOLOUR"

#Export functions to be able to use in chroot
export -f yes_no
export -f number_check
export -f prompt_info
export -f prompt_warning
export -f prompt_question
export -f prompt_different

export -f setup

#Setup
arch-chroot "$MOUNT_PATH" /bin/bash -c "setup"

#Export additional variables
export AUR_PACKAGES="$AUR_PACKAGES"
export SELECTED_GREETER="$SELECTED_GREETER"
export SERVICES="$SERVICES"

#Export additional functions
export -f check_connection
export -f failure
export -f Exit_

export -f post-install

#Arrange sudo for post-install
declare sudo_contents=""
sudo_contents="$(cat $MOUNT_PATH/etc/sudoers)"
printf "\n\n%s ALL=(ALL) NOPASSWD: ALL\n" "$USER_NAME" >> "$MOUNT_PATH/etc/sudoers"

#Post install
arch-chroot "$MOUNT_PATH" /bin/bash -c "post-install" || Exit_ $?

#Restore sudo
echo "$sudo_contents" > "$MOUNT_PATH/etc/sudoers"

#Backgrounds
prompt_info "Arranging backgrounds..."
if [ -d "assets" ]; then

    cp assets/Login_screen.png "$MOUNT_PATH/usr/share/backgrounds"
    cp assets/Background.png "$MOUNT_PATH/usr/share/backgrounds"

    #XFCE
    if [ -d "$MOUNT_PATH/usr/share/backgrounds/xfce" ]; then
    
        cp Background.png "$MOUNT_PATH/usr/share/backgrounds/xfce/xfce-verticals.png"
    fi
    
    #Login screen
    if pkg_find --quiet "lightdm"; then
    
        case $SELECTED_GREETER in
        
            "lightdm-slick-greeter")
        
                {
                    echo "[Greeter]"
                    echo "draw-user-backgrounds=false"
                    echo "draw-grid=false"
                    echo "enable-hidpi=auto"
                    echo "background=/usr/share/backgrounds/Login_screen.png"
                    echo "theme-name=Adwaita-dark"
                    echo "icon-theme-name=Adwaita"
                } > "$MOUNT_PATH/etc/lightdm/slick-greeter.conf"
            ;;
            
            "lightdm-gtk-greeter")
            
                declare bkg=""
                bkg=$(sed "s/#background=/background=\/usr\/share\/backgrounds\/Login_screen.png/g" "$MOUNT_PATH/etc/lightdm/lightdm-gtk-greeter.conf")
                
                sleep 1s
                
                if [ -n "$bkg" ]; then
                
                    echo "$bkg" > "$MOUNT_PATH/etc/lightdm/lightdm-gtk-greeter.conf"
                else
                
                    {
                        echo "[greeter]"
                        echo "background=/usr/share/backgrounds/Login_screen.png"
                    } > "$MOUNT_PATH/etc/lightdm/lightdm-gtk-greeter.conf"
                fi
            ;;
        esac
    fi
fi


#Unset before generating initramfs
unset NUMBER_CHECK
unset ANSWER
unset DEVICE
unset IS_ENCRYPT
unset ENCRYPT_PARTITION
unset SWAP_PARTITION
unset VOLGROUP
unset GRUB_ARGS
unset TMP_FILE

unset AUR_PACKAGES
unset SELECTED_GREETER
unset SERVICES

unset -f yes_no
unset -f number_check
#unset -f prompt_info
unset -f prompt_warning
unset -f prompt_question
unset -f prompt_different
unset -f setup
unset -f post-install
unset -f check_connection
unset -f failure
unset -f Exit_


#Initramfs
echo
prompt_info "Generating initramfs..."
arch-chroot "$MOUNT_PATH" /bin/bash -c "mkinitcpio -P"


Umount_


#http://patorjk.com/software/taag/#p=display&f=ANSI%20Shadow&t=!!%20Setup%20finished%20!!
printf "${LIGHT_CYAN}
██╗██╗    ███████╗███████╗████████╗██╗   ██╗██████╗     ███████╗██╗███╗   ██╗██╗███████╗██╗  ██╗███████╗██████╗     ██╗██╗
██║██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗    ██╔════╝██║████╗  ██║██║██╔════╝██║  ██║██╔════╝██╔══██╗    ██║██║
██║██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝    █████╗  ██║██╔██╗ ██║██║███████╗███████║█████╗  ██║  ██║    ██║██║
╚═╝╚═╝    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝     ██╔══╝  ██║██║╚██╗██║██║╚════██║██╔══██║██╔══╝  ██║  ██║    ╚═╝╚═╝
██╗██╗    ███████║███████╗   ██║   ╚██████╔╝██║         ██║     ██║██║ ╚████║██║███████║██║  ██║███████╗██████╔╝    ██╗██╗
╚═╝╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝         ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝     ╚═╝╚═╝
${NOCOLOUR}"

echo
printf "${LIGHT_GREEN}You can safely reboot now.${NOCOLOUR}"
echo

#Remove lock
rm -f "/tmp/$PROGRAM_NAME.lock"
