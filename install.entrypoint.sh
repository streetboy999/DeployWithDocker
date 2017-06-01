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


