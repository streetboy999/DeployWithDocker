#!/bin/bash

### Run in a docker container to install LSF ###
tar -zxvf $LSF_INSTALL_SCRIPT_FILE
cd $(pwd)/lsf9.1.3_lsfinstall
#cp install.config install.config.bak

# Create lsfadmin
id lsfadmin
if [ "$?" = "1" ];then
	useradd -m lsfadmin -s /bin/bash
	echo "lsfadmin:aaa123" | chpasswd
fi
#Modify LSF installation Script

cp install.config install.config.$LSF_CLUSTER_NAME
installFile="install.config.$LSF_CLUSTER_NAME"


sed -i '$a\LSF_TOP='"${LSF_TOP}"'' $installFile
sed -i '$a\LSF_ADMINS="lsfadmin"' $installFile
sed -i '$a\LSF_CLUSTER_NAME='"$LSF_CLUSTER_NAME"'' $installFile
sed -i '$a\LSF_MASTER_LIST='"$LSF_MASTER_NAME"'' $installFile
sed -i '$a\LSF_ENTITLEMENT_FILE='"$LSF_INSTALL_ENTITLEMENT_FILE"'' $installFile
sed -i '$a\LSF_TARDIR='"$LSF_TAR_DIR"'' $installFile

# Install
# When entrypoint is called the cwd is "/"


/opt/install.exp $installFile


# Configure LSF cluster after installation
if [ $IS_MC = "N" ]; then
	sed -i '$a\LSF_STRIP_DOMAIN='"$LSF_DOMAIN"'' $LSF_TOP/conf/lsf.conf
	for((i=$HOST_NUM-1;i>=1;i--))
	do
		HOSTSTRING="slave$i  !   !   1   3.5   ()   ()   ()"
		echo "$LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME" >> /opt/debug
		sed -i "/HOSTNAME/a $HOSTSTRING" $LSF_TOP/conf/lsf.cluster.$LSF_CLUSTER_NAME
	done
fi

if [ $IS_MC = "Y" ]; then
	echo "MC"

fi





