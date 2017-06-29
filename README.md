# DeployWithDocker
# Author: Justin Wu @ IBM
Install and deploy IBM LSF with Docker. It is easily to create an environment or destroy if if you don't need it any more.

How to use the tool?
1. At Beijing lab
(1) Logon on bjhc01

(2) Run "id" to check if your Unix account is in docker group. If not add it with following command
sudo usermod -aG docker <Your Unix account>
e.g. sudo usermod -aG docker cwwu

(3) Run docker ps to check if you can connec to the docker engine

(4) With your own Unix account run the script to start as below
./deploy.sh

(5) It supports 4 products: 
	1) Single Cluster Installation & Configuration (LSF9.1.3 and LSF10.1) + latest spk (LSF9.1.3 spk8 and LSF10.1 spk2)
	2) Multiple Cluster Installation & Configuration (LSF9.1.3 and LSF10.1) + latest spk  (LSF9.1.3 spk8 and LSF10.1 spk2)
	3) SAS PSS81 (PPM9.1) and PSS91 (PPM9.1.3) Installation & Configuration
	4) Data Manager 9.1.3 Installation & Configuration 
NOTE: For MC by default c1 is submission cluster. c2, c3, ... , cn is execution cluster. SndQ on c1 is send queue. RcvQ on other clusters is receive queue. 
      For SAS support due to the XGUI limitation the lab environment doesn't support it. It can run on Mac. 
      For Data Manager, by default master-id# is LSF master node. slave1-id# is dmd node. slave2-id# is I/O node. 

(6) How to login?
	1) After completing the deployment the tool lists all hosts that you can use. Or you can run docker ps to check what docker hosts are running. 
	2) Run dlogin <host name> e.g. 
	   dlogin master-id999
	3) After loggin host the user role is set to lsfadmin by default. LSF or SAS environment are sourced automatically. You can run LSF/PPM commands directly. 
	
(7) How to quit?
Just run "exit" in the docker host. 

(8) How to remove docker hosts
Use dsr id#. e.g. "dsr id999"

If you want to remove all hosts just run "dsr all"
NOTE: It is not recommended to run dsr all as it might delete others' hosts unless you really intend to do so. 

(9) User accounts in the docker host
By default it has 5 built users: root lsfadmin user1 user2 user3. Password is all "aaa123" (No double quotes)

(10) "sudo" command support
By default only "lsfadmin" is in sudoers. For user1, user2 and user3 you can put them into /etc/sudoers manually. 

(11) ssh passwordless support
After creating cluster nodes the ssh passwordless function is enabled. Considering the performance by default it can be enabled only if the # of hosts <=5 for root and lsfadmin. 

(12) Shared storage
While deploying an NFS node is created, which provides a data volume service. All nodes are mounted to /opt. 

(13) Network
While deploying a DNS server node is created. All hosts within the same ID can be accessed via hostname/IP.

(14) How to copy file in/out the docker containers (hosts)?
Use "docker cp" e.g. 
	You want to copy a file hello_world.txt from host machine to the docker host. docker cp /tmp/hello_world.txt master-id999:/opt
	You want to copy a file from the docker host to the host machine. docker cp master-id999:/opt/hello_world.txt /tmp


2. On your Mac
(1) Download and Install docker for Mac 
https://store.docker.com/editions/community/docker-ce-desktop-mac?tab=description

(2) Download and Install Xquartz (XGUI) for Mac
https://www.xquartz.org/releases/XQuartz-2.7.11.html

(2) Copy the deployment file from bjhc01
scp bjhc01.eng.platformlab.ibm.com:/scratch/support3/cwwu/Mybox/Project/Auto.tar.gz .

(3) Uncompress Auto.tar.gz to a location where you prefer

(4) Configure Xquartz properly to make clients able to connect to XGUI server. Open Xquartz -> Preferences -> Security -> Check "Allow connections from network clients"

(5) Enter the directory of Auto and execute setup4mac.sh


