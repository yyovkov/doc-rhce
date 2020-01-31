# Create RHCE Lab for self preparations

## Create classroom server

* Create classroom server

In order to emulate the correct way the RHCE exam, the network should be isolated and have no access to internet. But for initial installation we gonna need the internet access at least to access our kickstart file. Of course this could be embedded to the ISO, but my personal preferences are to keep as easier as possible for editing. And this way, for our installation we will install machine with two interfaces, and the we will remove one with access to internet.

``` bash
virt-install --name=TEST_dev__59200 --location=/srv/share/iso/CentOS/CentOS-7.0-1406-x86_64-DVD.iso --disk "pool=pool0,size=30,sparse=false,perms=rw" --extra-args="ks=http://castle.yyovkov.net/rhce-exam/ks-classroom.cfg ksdevice=eth1 ip=192.168.2.200 netmask=255.255.255.0 gateway=192.168.2.1 dns=192.168.2.2" --extra-args="linux setup=eth0,static,172.25.15.10,255.255.255.0,172.16.15.1,172.16.15.10,classroom.domain15.example.com" --graphics "vnc,listen=0.0.0.0,port=59200" --network bridge=rhce-exam  --network bridge=kvm0 --vcpus=2 --ram=2048 --os-variant=centos7.0 --wait=-1 --noreboot
```

* Remove interface with internet access

As all the installation finished and we are not going to need internet anymore, remove the devices connected to bridge `kvm`.

``` bash
ETH1_MAC=$(virsh domiflist TEST_dev__59200 | grep kvm0 | awk '{print $5}')
virsh detach-interface TEST_dev__59200 --type bridge --mac ${ETH1_MAC} --config
virsh start TEST_dev__59200
```

* Start Server

There is firstboot script installed on the system, that is confguring the 

``` bash
virsh start ...
```

## Create system1 and system2

``` bash

```

## Create Desktop Instance