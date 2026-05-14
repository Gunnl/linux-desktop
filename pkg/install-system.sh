#!/bin/bash

if [ "$EUID" -ne 0 ]
	then echo "must run as root"
		exit
fi

echo "****************************** installing system"
echo "******************** partitioning disk"
parted /dev/nvme0n1 --script mklabel gpt
parted -a optimal /dev/nvme0n1 --script mkpart primary fat32 1 1000MB
parted /dev/nvme0n1 --script set 1 esp on
parted /dev/nvme0n1 --script set 1 boot on
parted -a optimal /dev/nvme0n1 --script mkpart primary linux-swap 1000MB 5000MB
parted -a optimal /dev/nvme0n1 --script mkpart primary ext4 5000MB 100%

