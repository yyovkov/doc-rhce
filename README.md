# Prepare Lab Environment

This file contains information how to create home lab environment for RHCE

## Create Virtual Networks

* Create isolated (lab) network

``` bash
for nw in lab team-01 team-02
do
    export NWNAME="rhce-${nw}"
    export NETXML="/tmp/${NWNAME}.xml"
    cat > $NETXML << EOF
    <network>
    <name>$NWNAME</name>
    <bridge name="$NWNAME"/>
    </network>
EOF
    virsh net-define --file ${NETXML}
    virsh net-autostart ${NWNAME}
    virsh net-start ${NWNAME}
    rm ${NETXML}
done
```

## Install Virtual Machines

* Clone repo

``` bash
git clone https://github.com/yyovkov/doc-rhce.git /tmp/doc-rhce
```

* Setup Environmental variables

``` bash
C7CDROM="/var/lib/virtpools/system/CentOS-7.0-1406-x86_64-DVD.iso"
```

* Install RHCE-IPA

``` bash
virt-install --name=LAB__rhce_ipa__59120 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=10,sparse=false,perms=rw" \
    --initrd-inject="/tmp/doc-rhce/ks/rhce-ipa.conf" \
    --extra-args "ks=file:/rhce-ipa.conf" \
    --graphics "vnc,listen=0.0.0.0,port=59120" \
    --network network=rhce-lab \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0
```

* Install RHCE-DESKTOP

``` bash
virt-install --name=LAB__rhce_desktop__59123 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=20,sparse=false,perms=rw" \
    --initrd-inject="/tmp//doc-rhce/ks/rhce-desktop.conf" \
    --extra-args "ks=file:/rhce-desktop.conf" \
    --graphics "vnc,listen=0.0.0.0,port=59123" \
    --network bridge=test0 \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0 \
&& virsh attach-interface --domain LAB__rhce_desktop__59123 --type network --source rhce-lab --model virtio --config --live
```

* Install RHCE-01

``` bash
virt-install --name=LAB__rhce_01__59121 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=10,sparse=false,perms=rw" \
    --initrd-inject="/tmp/doc-rhce/ks/rhce-01.conf" \
    --extra-args "ks=file:/rhce-01.conf" \
    --graphics "vnc,listen=0.0.0.0,port=59121" \
    --network network=rhce-lab \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0
```

* Install RHCE-02

``` bash
virt-install --name=LAB__rhce_02__59122 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=10,sparse=false,perms=rw" \
    --initrd-inject="/tmp//doc-rhce/ks/rhce-02.conf" \
    --extra-args "ks=file:/rhce-02.conf" \
    --graphics "vnc,listen=0.0.0.0,port=59122" \
    --network network=rhce-lab \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0
```

## Post Install Actions

Ensure the virtual machines are up and running.

* Add additional network interfaces to _RHCE-01_ and _RHCE-02_

``` bash
for vm in LAB__rhce_01__59121 LAB__rhce_02__59122
do
    virsh attach-interface --domain $vm --type network --source rhce-team-01 --model virtio --config --live
    virsh attach-interface --domain $vm --type network --source rhce-team-02 --model virtio --config --live
done
```

## Making Snapshots of the lab from _box_ server

Snapshots are not required, but can be very useful in case something goes wrong with the excerceises. In that case, instead of reinstalling and re-configuring the machine

``` bash
for vm in LAB__rhce_ipa__59120 LAB__rhce_01__59121 LAB__rhce_02__59122
do
    virsh shutdown $vm
done
sleep 15 # Find better way to confirm the domain has been shutted down
for vm in LAB__rhce_ipa__59120 LAB__rhce_01__59121 LAB__rhce_02__59122
do
    virsh snapshot-create-as --domain $vm --name "initial_state" --description "Ready for RHCE exam preparation"
    virsh start $vm
done
```
