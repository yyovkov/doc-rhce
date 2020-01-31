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
git clone https://github.com/yyovkov/rhce-exam.git /tmp/rhce-exam
```

* Setup Environmental variables

``` bash
C7CDROM="/var/lib/virtpools/system/CentOS-7.0-1406-x86_64-DVD.iso"
```

* Install RHCE-DESKTOP

``` bash
virt-install --name=LAB__rhce_desktop__59123 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=20,sparse=false,perms=rw" \
    --initrd-inject="/tmp//rhce-exam/ks/rhce-desktop.ks" \
    --extra-args "ks=file:/rhce-desktop.ks" \
    --graphics "vnc,listen=0.0.0.0,port=59123" \
    --network bridge=test0 \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0 \
&& virsh attach-interface --domain LAB__rhce_desktop__59123 --type network --source rhce-lab --model virtio --config --live

```

* Install RHCE-IPA

``` bash
virt-install --name=LAB__rhce_ipa__59120 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=10,sparse=false,perms=rw" \
    --initrd-inject="/tmp/rhce-exam/ks/rhce-ipa.ks" \
    --extra-args "ks=file:/rhce-ipa.ks" \
    --graphics "vnc,listen=0.0.0.0,port=59120" \
    --network network=rhce-lab \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0 &
```

* Install RHCE-01

``` bash
virt-install --name=LAB__rhce_01__59121 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=10,sparse=false,perms=rw" \
    --initrd-inject="/tmp/rhce-exam/ks/rhce-01.ks" \
    --extra-args "ks=file:/rhce-01.ks" \
    --graphics "vnc,listen=0.0.0.0,port=59121" \
    --network network=rhce-lab \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0 &
```

* Install RHCE-02

``` bash
virt-install --name=LAB__rhce_02__59122 \
    --location="${C7CDROM}" \
    --disk "pool=local,size=10,sparse=false,perms=rw" \
    --initrd-inject="/tmp//rhce-exam/ks/rhce-02.ks" \
    --extra-args "ks=file:/rhce-02.ks" \
    --graphics "vnc,listen=0.0.0.0,port=59122" \
    --network network=rhce-lab \
    --vcpus=2 --ram=1024 \
    --os-variant=centos7.0 &
```

## Post Install Actions

Ensure the virtual machines are up and running.

* Add additional network interfaces to _RHCE-01_ and _RHCE-02_

``` bash
for vm in LAB__rhce_01__59121 LAB__rhce_02__59122
do
    virsh attach-interface --domain $vm --type network --source rhce-lab-01 --model virtio --config --live
    virsh attach-interface --domain $vm --type network --source rhce-lab-02 --model virtio --config --live
done
```

### Setup IPA server

Execute below task on _rhce-ipa_

* Install and configure IPA server

``` bash
sudo firewall-cmd --permanent --add-service={http,https,ldap,ldaps,kerberos,dns,kpasswd,ntp,smtp}
sudo firewall-cmd --reload
sudo ipa-server-install --setup-dns \
    --realm EXAMPLE.COM \
    --ds-password ldap_password \
    --admin-password password \
    --domain example.com \
    --mkhomedir \
    --hostname $(hostname -s | xargs).example.com \
    --ip-address 172.24.11.120 \
    --no-forwarders \
    --no-host-dns \
    -U
```

* Change network settings

``` bash
export ipaddr=$(hostname -I | xargs) # xargs trim white space at the end
sudo nmcli connection modify "System eth0" connection.id "eth0"
sudo nmcli con mod eth0 ipv4.dns "172.24.11.120"
sudo nmcli con up eth0
```

``` bash
sudo cp /etc/ipa/ca.crt /var/ftp/pub/lab_ca.crt
```

* Create kerberos ticket

``` bash
echo 'password' | kinit admin
klist
```

* Set admin permission to change  user password expiration

``` bash
ipa pwpolicy-mod --maxlife=9999
ipa pwpolicy-mod --minlife=0
```

* Create users in IPA

``` bash
ipa config-mod --defaultshell=/bin/bash
echo 'password' | \
    ipa user-add ldapuser1\
    --first=Ldap\
    --last=User1 \
    --password
echo 'password' | \
    ipa user-add lisa \
    --first=Lisa \
    --last=Brighton \
    --password
echo 'password' | \
    ipa user-add smbanonymous \
    --first=Samba \
    --last=Anonymous \
    --password
```

* Create hosts in IPA

``` bash
ipa host-add --ip-address 172.24.11.121 rhce-01.example.com
ipa host-add --ip-address 172.24.11.122 rhce-02.example.com
```

* Create the NFS service entry in the IdM domain:

``` bash
ipa service-add nfs/rhce-01.example.com
ipa service-add nfs/rhce-02.example.com
echo password | sudo kinit admin
sudo ipa-getkeytab -s rhce-ipa.example.com \
    -p  host/rhce-01.example.com \
    -k /var/ftp/pub/rhce-01.keytab
sudo ipa-getkeytab -s rhce-ipa.example.com \
    -p host/rhce-02.example.com \
    -k /var/ftp/pub/rhce-02.keytab
sudo ipa-getkeytab -s rhce-ipa.example.com \
    -p  nfs/rhce-01.example.com \
    -k /var/ftp/pub/rhce-01.keytab
sudo ipa-getkeytab -s rhce-ipa.example.com \
    -p nfs/rhce-02.example.com \
    -k /var/ftp/pub/rhce-02.keytab
sudo chmod 644 /var/ftp/pub/*.keytab
```

* Add example.com domain MX dns record

``` bash
ipa dnsrecord-add example.com. @ --mx-rec="10 rhce-ipa"
```

* Create protected.example.com certificate

``` bash
ipa dnsrecord-add example.com protected --cname-rec rhce-01
ipa dnsrecord-add example.com virtual --cname-rec rhce-01
ipa dnsrecord-add example.com logic --cname-rec rhce-01
ipa dnsrecord-add example.com sales --cname-rec rhce-01
ipa host-add protected.example.com
ipa service-add HTTP/protected.example.com
ipa service-add-host --hosts=rhce-ipa.example.com HTTP/protected.example.com
sudo ipa-getcert request -r \
    -f /etc/pki/tls/certs/protected.example.com.crt \
    -k /etc/pki/tls/private/protected.example.com.key \
    -N CN=protected.example.com \
    -D protected.example.com \
    -K HTTP/protected.example.com
sudo cp /etc/pki/tls/certs/protected.example.com.crt /etc/pki/tls/private/protected.example.com.key /var/ftp/pub
```

* Configure SMTP server

``` bash
sudo postconf -e 'mynetworks = 127.0.0.0/8, 172.24.11.0/24'
sudo postconf -e 'inet_interfaces = all'
sudo postconf -e 'mydomain = example.com'
sudo postconf -e 'mydestination = $myhostname, localhost.$mydomain, localhost $mydomain'
sudo systemctl restart postfix
```

## Setup lab servers (_rhce-01_ and _rhce-02_)

This commands should be executed on the other two servers that are forming the RHCE lab - _rhce-01_ and _rhce-02_

* Change network configuration

``` bash
sudo nmcli connection modify "System eth0" connection.id "eth0"
sudo nmcli con mod eth0 ipv4.dns 172.24.11.120
sudo nmcli con up eth0
```

* Remove unwanted network connections

``` bash
sudo nmcli connection delete 'Wired connection 1'
sudo nmcli connection add con-name eth1 type ethernet ifname eth1 autoconnect yes
sudo nmcli connection delete 'Wired connection 2'
sudo nmcli connection add con-name eth2 type ethernet ifname eth2 autoconnect yes
```

## Making Snapshots of the lab from _box_ server

Snapshots are not required, but can be very useful in case something goes wrong with the excerceises. In that case, instead of reinstalling and re-configuring the machine

``` bash
for vm in LAB_rhce_ipa__59120 LAB_rhce_01__59121 LAB_rhce_02__59122
do
    virsh shutdown $vm
done
sleep 15 # Find better way to confirm the domain has been shutted down
for vm in LAB_rhce_ipa__59120 LAB_rhce_01__59121 LAB_rhce_02__59122
do
    virsh snapshot-create-as --domain $vm --name "initial_state" --description "Ready for RHCE exam preparation"
done
```

## Start Lab Machines

``` bash
for vm in LAB_rhce_ipa__59120 LAB_rhce_01__59121 LAB_rhce_02__59122
do
    virsh start $vm
done
```
