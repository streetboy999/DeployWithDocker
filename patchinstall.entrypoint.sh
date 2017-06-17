#!/bin/bash

## Start a container to install LSF patches
# The Input environment variabels are LSF_VERSION, LSF_PATCH_FILE, LSF_TOP and NFS


# Create lsfadmin
id lsfadmin
if [ "$?" = "1" ];then
	useradd -m lsfadmin -s /bin/bash
	echo "lsfadmin:aaa123" | chpasswd
fi


# Go to LSF install dir
cd $LSF_TOP/$LSF_VERSION/install

# In LSF10.1, sometimes it requires to accept the license agreement even though chose silent installation
# Pass "1" to the patch installation script
echo 1 | ./patchinstall --silent -f $LSF_TOP/conf/lsf.conf $LSF_PATCH_FILE





