#!/bin/bash

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
wipefs -a /dev/nvme0n1
parted /dev/nvme0n1 --script mklabel gpt
parted -a optimal /dev/nvme0n1 --script mkpart primary fat32 1 1000MB
parted /dev/nvme0n1 --script set 1 esp on
parted /dev/nvme0n1 --script set 1 boot on
parted -a optimal /dev/nvme0n1 --script mkpart primary 1000MB 100%

mkfs.fat -F 32 /dev/nvme0n1p1

# create file-based password
dd if=/dev/urandom of=/root/secret.key bs=1024 count=2
sudo chmod 0400 /root/secret.key

cryptsetup luksFormat /dev/nvme0n1p2 /root/secret.key
cryptsetup luksAddKey /dev/nvme0n1p2 /root/secret.key --key-file=/root/secret.key

cryptsetup luksOpen /dev/nvme0n1p2 root --key-file=/root/secret.key

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
mount /dev/nvme0p1 /mnt/efi

