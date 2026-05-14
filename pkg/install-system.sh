#!/bin/bash

if [ "$EUID" -ne 0 ]
	then echo "must run as root"
		exit
fi

echo "*********** installing system"

