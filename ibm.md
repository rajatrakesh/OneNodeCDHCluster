# IBM Cloud setup notes

Confirm the extra disk is mounted at `/dev/xvdc`

```
$ lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
xvda    202:0    0  100G  0 disk
├─xvda1 202:1    0    1G  0 part /boot
└─xvda2 202:2    0   99G  0 part /
xvdc    202:32   0  500G  0 disk             <---- HERE!
xvdp    202:240  0   64M  0 disk
```

Now you can start the bootstrap script

```
$ sudo su -
$ yum install -y git
$ git clone https://github.com/fabiog1901/OneNodeCDHCluster.git
$ cd OneNodeCDHCluster
$ chmod +x ibm_setup.sh
$ ./ibm_setup.sh ibm templates/ibm_template.json /dev/xvdc
```

## Notes

If you are running RHEL instead of CentOS, you must run the below before the script, in order to install the EPEL repo:
```
$ rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
```

## CDSW limitation on this deployment

Login into CDSW, go to Admin > Engines and add the following

- to **Environmental variables**:

```
HADOOP_CONF_DIR   /etc/hadoop/conf/
```

In order to access HDFS on the CDH cluster, you must specify the private IP of the HDFS service using the `-fs` option, eg:

```
!hdfs dfs -fs hdfs://10.243.0.15:8020 -put my_file.txt /user/$HADOOP_USER_NAME
!hdfs dfs -fs hdfs://10.243.0.15:8020 -ls
Found 1 items
-rw-r--r--   1 admin admin     230996 2019-08-14 15:07 my_file.txt
```

You won't be able to run Spark job out of CDSW for the moment.


