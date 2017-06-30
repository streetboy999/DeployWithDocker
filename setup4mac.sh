#!/bin/bash

## This script will help you copy all necessary files and setup the environment automatically

IMAGE_FILE_GZ="ubuntu.17.04.v4.tar.gz"
IMAGE_FILE_DNS_GZ="phensley.docker-dns.latest.tar.gz"
IMAGE_FILE_TAR="ubuntu.17.04.v4.tar"
IMAGE_FILE_DNS_TAR="phensley.docker-dns.latest.tar"

installDir="/scratch/support3/cwwu/Mybox/tmp/docker/Raw_Packages.tar.gz"
tarFile="Raw_Packages.tar.gz"

# Check if docker and Xquartz is installed
which docker > /dev/null 2>&1
if [ $? = "1" ]; then
        echo "Docker is not installed. Exiting..."
        exit
fi

which Xquartz > /dev/null 2>&1
if [ $? = "1" ]; then
        echo "Xquartzr is not installed. Exiting..."
        exit
fi

docker ps > /dev/null 2>&1

if [ $? = "1" ]; then
        echo "Docker service is not started yet. Please start it. Exiting.."
        exit
fi


if [ ! -d Data ];then
	mkdir Data
fi

CWD=$(pwd)
DataDir=$(pwd)/Data

#installDir=/tmp/cwwu

echo "Copy all necessary installation pakcages to your Mac. All files are about 2GB, please wait..."

echo "You need to input the root password of bjhc01 (aaa123) manually here. Please wait for a few seconds until scp command comes out..."

scp root@bjhc01.eng.platformlab.ibm.com:$installDir $DataDir

if [ $? = "1" ]; then
	echo "Copy files error. Exiting..."
	exit
fi

cd $DataDir

echo -e "\nEntering $DataDir"

echo "Uncompressing Data File..."
tar -zxvf $tarFile 

if [ $? = "1" ]; then
	echo "Uncompress error. Exiting..."
	exit
fi

echo -e "\nThanks for your patience. All your files are in place!"
echo -e "\nGenerating configure.lsf file..."

# Setup configure.lsf

cd $CWD

if [ ! -e $(pwd)/configure.lsf ]; then
	#echo "$(pwd)/configure.lsf doesn't exist"
	touch $(pwd)/configure.lsf
	chmod 666 $(pwd)/configure.lsf
else
	#echo "$(pwd)/configure.lsf exists"
	cp $(pwd)/configure.lsf $(pwd)/configure.lsf.old
	rm $(pwd)/configure.lsf
	touch $(pwd)/configure.lsf
	chmod 666 $(pwd)/configure.lsf
fi

# Redirect outputs to configure.lsf
exec 6>&1
exec 1>$(pwd)/configure.lsf


echo '## This file defines all environment parameters used by the tool'
echo "INSTALL_PACKAGE_DIR_FOR_LSF913=$DataDir/Raw_Packages/LSF9.1.3/OriginalPackage"
echo "INSTALL_PACKAGE_DIR_FOR_LSF101=$DataDir/Raw_Packages/LSF10.1/OriginalPackage"
echo "INSTALL_PACKAGE_DIR_FOR_SAS_PSS81=$DataDir/Raw_Packages/SASPSS81"
echo "INSTALL_PACKAGE_DIR_FOR_SAS_PSS91=$DataDir/Raw_Packages/SASPSS91"
echo "INSTALL_PACKAGE_DIR_FOR_DM913=$DataDir/Raw_Packages/DM9.1.3"
echo "SPK_DIR_FOR_LSF913=$DataDir/Raw_Packages/LSF9.1.3/SPK/spk8"
echo "SPK_DIR_FOR_LSF101=$DataDir/Raw_Packages/LSF10.1/SPK/spk2"

echo '# The image file that you choose to create docker containers'
echo "IMAGE=ubuntu:17.04.v4"
echo "IMAGE4SAS=ubuntu:17.04.v4"

exec 1>&6
exec 6>&-

echo "configure.lsf is generated"


# Load image

echo -e "\nLoading the image to docker..."

IMAGE_DIR=$DataDir/Raw_Packages/Images

if [ ! -d $IMAGE_DIR ]; then
	echo "The image directory $IMAGE_DIR doesn't exist. Please check. Exiting..."
	exit
fi
cd $IMAGE_DIR


tar -zxvf $IMAGE_FILE_GZ -C .

if [ $? = "1" ]; then
        echo "Image file $IMAGE_FILE_GZ uncompress error. Exiting..."
	exit
fi

tar -zxvf $IMAGE_FILE_DNS_GZ -C .

if [ $? = "1" ]; then
	echo "Image file $IMAGE_FILE_DNS_GZ uncompress error. Exiting..."
	exit
fi

docker load -i $IMAGE_FILE_TAR

if [ $? = "1" ]; then
	echo "Docker loads image file error. Exiting..."
	exit
fi

docker load -i $IMAGE_FILE_DNS_TAR

if [ $? = "1" ]; then
        echo "Docker loads image file error. Exiting..."
	exit
fi

echo "Image is loaded successfully!"


cd $CWD
echo "Enter $CWD"

if [ -e $(pwd)/user_id.track ]; then
	touch $(pwd)/user_id.track
	chmod 666 $(pwd)/user_id.track
fi


echo -e "\nWill link following commands to /usr/local/bin and please input your Mac sudo password.\n   dlogin dsr myhosts allhosts\n"


sudo ln -s $(pwd)/CLI/dlogin /usr/local/bin/dlogin
sudo ln -s $(pwd)/CLI/dsr /usr/local/bin/dsr
sudo ln -s $(pwd)/CLI/myhosts /usr/local/bin/myhosts
sudo ln -s $(pwd)/CLI/allhosts /usr/local/bin/allhosts
sudo ln -s $(pwd)/user_id.track /usr/local/bin/user_id.track



echo -e "\nCONGRATULATIONS!\nThe environment is setup completely and you can run ./deploy to setup your cluster now!"





