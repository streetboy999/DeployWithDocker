#!/bin/bash

## This script will help you copy all necessary files and setup the environment automatically

IMAGE_FILE_GZ="ubuntu.17.04.v4.tar.gz"
IMAGE_FILE_TAR="ubuntu.17.04.v4.tar"

if [ ! -d Data ];then
	mkdir Data
fi

CWD=$(pwd)
DataDir=$(pwd)/Data

installDir "/scratch/support3/cwwu/Mybox/tmp/docker/Raw_Packages"
#installDir=/tmp/cwwu

echo "Copy all necessary installation pakcages To your mac. All files are about 3GB, please wait..."

expect<<-EOF
set timeout 30
spawn scp -r root@bjhc01.eng.platformlab.ibm.com:$installDir $DataDir/ 
expect "password"
send "aaa123\r"
expect eof
EOF

echo "Thanks for your patience. All your files are in place!"
echo -e "\nGenerating configure.lsf file..."

# Setup configure.lsf

if [ ! -e $(pwd)/configure.lsf ]; then
	touch $(pwd)/configure.lsf
	chmod 666 $(pwd)/configure.lsf
else
	rm $(pwd)/configure.lsf
fi

exec 6>&1
exec 1>$(pwd)/configure.lsf


echo '## This file defines all environment parameters used by the tool'
echo "INSTALL_PACKAGE_DIR_FOR_LSF913=$DataDir/Raw_Packages/LSF9.1.3/OriginalPackage"
echo "INSTALL_PACKAGE_DIR_FOR_LSF101=$DataDir/Raw_Packages/LSF10.1/OriginalPackage"
echo "INSTALL_PACKAGE_DIR_FOR_SAS_PSS91=$DataDir/Raw_Packages/PPM/SASPSS81"
echo "INSTALL_PACKAGE_DIR_FOR_SAS_PSS91=$DataDir/Raw_Packages/PPM/SASPSS91"
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
cd $IMAGE_DIR
tar -zxvf $IMAGE_FILE_GZ -C .
docker load -i $IMAGE_FILE_TAR

echo "Image is loaded!"

echo -e "\nWill link following commands to /usr/local/bin and please input sudo password.\ndlogin dsr myhosts allhosts\n"

if [ -e $(pwd)/user_id.track ]; then
	touch $(pwd)/user_id.track
	chmod 666 $(pwd)/user_id.track
fi

sudo ln -s $(pwd)/CLI/dlogin /usr/local/bin/dlogin
sudo ln -s $(pwd)/CLI/dsr /usr/local/bin/dsr
sudo ln -s $(pwd)/CLI/myhosts /usr/local/bin/myhosts
sudo ln -s $(pwd)/CLI/allhosts /usr/local/bin/allhosts
sudo ln -s $(pwd)/user_id.track /usr/local/bin/user_id.track

echo -e "\nCONGRATULATIONS!\nThe environment is setup completely and you can run ./deploy to setup your cluster now!"





