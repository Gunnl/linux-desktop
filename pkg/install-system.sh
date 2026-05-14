#!/bin/bash

hostname="archscape"
diskDrive="/dev/nvme0n1"
partitionEFI="p1"
partitionRoot="p2"
rootPassword="password1234"
diskPassword="password1234"
userLogin="aUser"

if [ "$EUID" -ne 0 ]
	then echo "must run as root"
		exit
fi

# exit on any error
set -e

echo "****************************** installing system"
echo "******************** partitioning disk"
read -p "*** WARNING *** This will erase all your data! Do you wish to continue? (y/n): " response
if ! [[ "$response" == "y" || "$response" == "Y" || "$response" == "yes" || "$response" == "Yes" || "$response" == "YES" ]]
then
	echo "Aborting!"
	exit 0
fi
wipefs -a "$diskDrive"
parted "$diskDrive" --script mklabel gpt
parted -a optimal "$diskDrive" --script mkpart primary fat32 1 1000MB
parted "$diskDrive" --script set 1 esp on
parted "$diskDrive" --script set 1 boot on
parted -a optimal "$diskDrive" --script mkpart primary 1000MB 100%

mkfs.fat -F 32 "$diskDrive$partitionEFI"

# create file-based password
#dd if=/dev/urandom of=/root/secret.key bs=1024 count=2
#sudo chmod 0400 /root/secret.key

#cryptsetup luksFormat /dev/nvme0n1p2 /root/secret.key
#cryptsetup luksAddKey /dev/nvme0n1p2 /root/secret.key --key-file=/root/secret.key

#cryptsetup luksOpen /dev/nvme0n1p2 root --key-file=/root/secret.key

cryptsetup luksFormat --type luks2 "$diskDrive$partitionRoot" <<< "$diskPassword"
cryptsetup open "$diskDrive$partitionRoot" root <<< "$diskPassword"

mkfs.btrfs /dev/mapper/root

mount /dev/mapper/root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@swap

# unmount partition and mount volumes
umount /mnt
mount -o subvol=@ /dev/mapper/root /mnt
mkdir -p /mnt/home
mkdir -p /mnt/swap
mount -o subvol=@home /dev/mapper/root /mnt/home
mount -o subvol=@swap /dev/mapper/root /mnt/swap

# mount EFI partition
mkdir -p /mnt/efi
mount "$diskDrive$partitionEFI" /mnt/efi

pacman -Syy

pacman -S --noconfirm reflector

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
reflector -c "NL" -f 12 -l 10 -n 12 --save /etc/pacman.d/mirrorlist

# install base
pacstrap -K /mnt base linux linux-firmware vim wget networkmanager dnsmasq wpa_supplicant btrfs-progs man sudo sbctl

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

# setup timezone
ln -sf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
hwclock --systohc

# locale-gen
sed -i 's/#en_US.UTF-8//g' /etc/locale.gen
echo "LANG=en_US.UTF-8"

# hostname configuration
echo "$hostname" > /etc/hostname
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts

# set root password
passwd "$rootPassword" | passwd

# configure mkinitcpio.conf
sed -i '/^#/! s/filesystems/sd-encrypt &/g' /etc/mkinitcpio.conf

# network configuration
echo "[main]\ndns=dnsmasq" > /etc/NetworkManager/conf.d/dns.conf
echo "cache-size=2000" > /etc/NetworkManager/dnsmasq.d/cache.conf

# install intel microcode
pacman -S --noconfirm intel-ucode

# install grub
pacman -S --noconfirm grub
grub-install --target=x86-pc
grub-mkconfig -o /boot/grub/grub.cfg

exit

