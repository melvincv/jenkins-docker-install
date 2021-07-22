#!/bin/bash
# Script used to set up Docker and Docker Compose using a data dir on a separate disk.

# Check if run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

read -p "Update and upgrade Ubuntu packages? (Reboot required) [n]: " UPGRADE
UPGRADE=${UPGRADE:-n}
if [ "$UPGRADE" == "y" ]; then
apt update && apt dist-upgrade -y
reboot
fi

echo "***Define user and data disk device***"
read -p "Enter user name [user]: " MYUSER
MYUSER=${MYUSER:-user}
read -p "Enter public SSH key for ${MYUSER}: " PUBKEY
read -p "Enter data disk device [xvdb]: " DEVNAME
DEVNAME=${DEVNAME:-xvdb}

echo
echo "***Check if user exists, else create user***"
getent passwd $MYUSER > /dev/null 2>&1
if [ "$?" -ne 0 ]; then
	adduser $MYUSER
	usermod -aG sudo $MYUSER
	mkdir /home/${MYUSER}/.ssh
	echo $PUBKEY > /home/${MYUSER}/.ssh/authorized_keys
	chown -R $MYUSER:$MYUSER /home/${MYUSER}/.ssh
	chmod 700 /home/${MYUSER}/.ssh
	chmod 600 /home/${MYUSER}/.ssh/authorized_keys
else
	echo "User exists."
fi

echo
echo "***Check for Docker, Install Docker***"
if [ -f "$(which docker)" ]; then
	echo "Docker is present. No need to run this script"
	exit
else
	curl -fsSL https://get.docker.com -o get-docker.sh
	sh get-docker.sh
	usermod -aG docker $MYUSER
fi

echo
echo "***Format the data disk***"
read -p "Are you sure you want to format /dev/${DEVNAME} [n]? " FMT
FMT=${FMT:-n}
if [ "$FMT" == "y" ]; then
	mkfs.ext4 /dev/${DEVNAME}

	echo "6. Get Data Disk UUID"
	fs_uuid=$(blkid -o value -s UUID /dev/${DEVNAME}) 
	echo ${fs_uuid}

	echo "7. Create mount point"
	mkdir /data

	echo "8. Backup the fstab file"
	if [ -f "/etc/fstab.mel.bk" ]; then
		rm -f /etc/fstab
		cp -av /etc/fstab.mel.bk /etc/fstab
		rm -f /etc/fstab.mel.bk
	fi
	cp -av /etc/fstab /etc/fstab.mel.bk


	echo "9. Edit the fstab file"
	cat <<-EOF >> /etc/fstab
	UUID="$fs_uuid" /data ext4 defaults 0 0
	EOF
	
	echo "10. Mount the data disk"
	mount -a

	echo "11. Create the Docker Data Dir"
	mkdir /data/docker

	echo "12. Change Docker Data Directory, restart Docker"
	cat <<-EOF > /etc/docker/daemon.json
	{
		"data-root":"/data/docker"
	}
	EOF
	systemctl restart docker
fi

echo
echo "13. Install Docker Compose"
read -p "Do you want to install Docker Compose? [n]: " DC
DC=${DC:-n}
if [ "$DC" == "y" ]; then
	curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	curl \
		-L https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/bash/docker-compose \
		-o /etc/bash_completion.d/docker-compose
	docker-compose --version
fi

