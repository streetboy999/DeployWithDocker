# DeployWithDocker
# Author: Chunwei Wu @ IBM
Install and deploy IBM LSF family products with Docker. It is easily to create an environment or destroy it if you don't need it any more.

Installation

1. On your Mac
(1) Download and Install docker for Mac
https://store.docker.com/editions/community/docker-ce-desktop-mac?tab=description

(2) Download and Install Xquartz (XGUI) for Mac
https://www.xquartz.org/releases/XQuartz-2.7.11.html

(2) Copy the deployment file
Beijing Lab: scp bjhc01.eng.platformlab.ibm.com:/scratch/support3/cwwu/Mybox/Project/Auto.tar.gz .
Toronto Lab: scp intel4.eng.platformlab.ibm.com:/scratch/support/cwwu/project/auto_deploy_with_docker/Auto.tar.gz .

(3) Uncompress Auto.tar.gz to a location where you prefer

(4) Configure Xquartz properly to make clients able to connect to XGUI server. Open Xquartz -> Preferences -> Security -> Check "Allow connections from network clients"

(5) Start docker service on your Mac. Run docker ps to double check if it is started successfully.

(6) Enter the directory of "Auto" and execute "setup4mac.sh"


Usage
1. Menu
After installation you can enter the diretory "Auto" created by setup4mac.sh script. Run ./deploy.sh
IBM LSF Automatic Deployment Tool (beta)
What products do you want to deploy:
1. LSF
2. Multiple Cluster
3. SAS (LSF+PPM)
4. Data Manager

It supports 4 products now. You can choose the products / Version according to the prompts.

2. Some definition
- Share Directory
All nodes share the same directory - /opt   If you want to copy any files and let each node to access it I suggest you use this dir /opt/SHARE_DIR. With it you will not have any permission issue.
Outside docker (on the host) you can copy in/out files with the command:
Copy to docker: docker cp <local file> <container_name>:/opt/SHARE_DIR   e.g. docker cp testfile master-id001:/opt/SHARE_DIR
Copy from docker: docker cp master-id001:/opt/SHARE_DIR/<file> .

- CLI
(1) Logon LSF host (docker container)
dlogin
After installation a command "dlogin" is copied to your /usr/local/bin, you can use it to enter the docker container (the created LSF nodes). For example, you created a cluster with 2 hosts: master-id001 and slave1-id001. You can logon it as below:
dlogin master-id001
After login you will be set to "lsfadmin" as the default user and all LSF (or add-ons) profile will be sourced automatically.

(2) Show what hosts were created
myhosts

e.g.
chunweis-mbp:Auto cwwu$ myhosts

cwwu's created hosts:

----------------------------------
ID=id364 Cluster_NAME=lsf101spk4
slave4-id364
slave3-id364
slave2-id364
slave1-id364
master-id364

(3) Remove a cluster
Remove all containers: dsr all
Remove a clsuter: dsr idxxx

(4) Shutdown hosts
dshutdown [all | idxxx | hostname]

(5) Startup hosts
dstart [all | idxxx | hostname]

- User definition
By installation I only set 5 users which are "root", "lsfadmin", "user1", "user2" and "user3" and the password is all "aaa123"

- DNS support
While creating the docker containers, a 3rd-party DNS container is also created. All those ndoes can be resolved by each other via the DNS. You can also connect to the outside world via your host machine DNS.

- LSF nodes (docker containers) name definition
For single cluster they are master-idxxx, slave1-idxxx, slave2-idxxx etc.
For MC they are c1-master-idxxx, c1-slave1-idxxx, c1-slave2-idxxx ... and c2-master-idxxx, c2-slave1-idxxx, c2-slave2-idxxx ... and c3... etc

- Some pre-configured settings
To save the users' configuraring time I configured the cluster while installation.
(1) MC
clusters are configured to "forward" mode. c1 is the default submission cluster and all other clusters are execution clusters. "SndQ" is the submission queue and "RcvQ" is the execution queue.

(2) Data Manager
It supports single cluster mode and MC mode (currently only supporting LSF9.1.3 and DM9.1.3). slave1-idxxx is set to DM server, slave2-idxxx is set to the I/O node. In single cluster mode, /opt/dmsingle/dmsa is the default staging area. In MC mode, still c1 is the submission cluster c2, c3 ... are execution clusters. The staging area is /opt/c1/dmsa, /opt/c2/dmsa, /opt/c3/dmsa and so on.

(3) PPM
You must install Xquartz to display the XGUI for PPM. Currently it only supports PSS8.1 (PM9.1) and PSS9.1 (PM9.1.3). Of course it is not hard to add new versions. By default jfd runs on the master node. Although it is SAS version, for internal testing I put floweditor inside. You can launch flowmanager, floweditor via the following comamnds:
floweditor &
flowmanager &

And a X-GUI will be poped up.

(4) LSF Explore
It supports the latest LSF Explore 10.2. (NOTE: LSF10.1 spk4 must be installed, choose the latest patch while installation)
An ElasticSearch will be installed seperately by the tool. Currently there can be only LSF Explore instance started. In another words, all your cluster connects to the same instance. You can choose if you want to install/connect to LSF Explore while running the tool.

On your Mac you can access http://127.0.0.1:8080 to use LSF Explore

(5) Other common tools
You can use yum to install any packages. Just make sure your host machine can access yum. For Toronto user there is no difference, for Chinese user the proxy is needed. Others like gdb are all installed by default. You can debug it in it as usually.

- Configuration
After running setup4mac.sh a configuration file named "configure.lsf" under "Auto" is created. Generally you don't need to touch it. If you want to change some files location e.g. Ask the tool to install LSF10.1 spk3 rather than spk4, you can configure it accordingly.

- Limitation
(1) Restarting the container will cause DNS to assign a new IP to the container. And the cluster might not be able to recogonize (2) the host any more. So this function is not supported well for now.
(3) OS image: By default it supports centos and ubuntu. redhat should be no difference but not tested yet.
For some kernel level testing like CPU time, as docker container replies on the host machine they might be not accurated. Suggest do feature level testing with the tool.
(4) Don't use special characters to be the cluster name to avoid some unknow errors during docker container creation. Recommended name, using default or like this "lsf101spk4samsungtest"






2. At Beijing lab (The docker in Beijing lab was destroyed. So ignore this for now)
(1) Logon on bjhc01

(2) Run "id" to check if your Unix account is in docker group. If not add it with following command
sudo usermod -aG docker <Your Unix account>
e.g. sudo usermod -aG docker cwwu

(3) Run docker ps to check if you can connec to the docker engine

(4) With your own Unix account run the script to start as below
./deploy.sh

(5) It supports 5 products: 
	1) Single Cluster Installation & Configuration (LSF9.1.3 and LSF10.1) + latest spk (LSF9.1.3 spk8 and LSF10.1 spk2)
	2) Multiple Cluster Installation & Configuration (LSF9.1.3 and LSF10.1) + latest spk  (LSF9.1.3 spk8 and LSF10.1 spk2)
	3) SAS PSS81 (PPM9.1) and PSS91 (PPM9.1.3) Installation & Configuration
	4) Data Manager 9.1.3 Installation & Configuration 
NOTE: For MC by default c1 is submission cluster. c2, c3, ... , cn is execution cluster. SndQ on c1 is send queue. RcvQ on other clusters is receive queue. 
      For SAS support due to the XGUI limitation the lab environment doesn't support it. It can run on Mac. 
      For Data Manager, by default master-id# is LSF master node. slave1-id# is dmd node. slave2-id# is I/O node. In MC+DM environment, by default 
      c1 is the submission cluster. You can specify any hosts in cluster c1 as the data source host. 
    5) LSF Explorer
    When you install LSF (both single cluster or MC), you will be asked if you want to be monitored by LSF Explorer. (default is yes)
    The tool will install LSF Explorer (server, elastic search and client). 
    From your browser access http://bjhc01.eng.platformlab.ibm.com:8080
    NOTE: If you run the tool on your mac just access http://127.0.0.1:8080

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





