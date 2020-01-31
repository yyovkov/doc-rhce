auth --enableshadow --passalgo=sha512
cdrom
graphical
unsupported_hardware
firstboot --disable
eula --agreed
ignoredisk --only-use=vda
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
firewall --enabled --ssh --ftp --http --service=dns
selinux --enforcing
reboot

# Network information
network --bootproto=static --device=eth0 --ip=172.24.11.120 --netmask=255.255.255.0 --gateway=172.24.11.1 --noipv6 --nameserver=172.24.11.120 --onboot=yes
network  --hostname=rhce-ipa.example.com

# Root password
rootpw --plaintext iparootpassword
# System services
services --enabled="chronyd" --enabled="vsftpd"
# System timezone
timezone Europe/Sofia --isUtc
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=vda
# Partition clearing information
clearpart --all --initlabel --drives=vda
# Disk partitioning information
part /boot --fstype="xfs" --ondisk=vda --size=1000
part swap --fstype="swap" --ondisk=vda --recommended
part pv.01 --fstype="lvmpv" --ondisk=vda --size=1 --grow
volgroup vg_rhce-ipa --pesize=4096 pv.01
logvol /  --fstype="xfs" --grow --percent=100 --name=root --vgname=vg_rhce-ipa

%packages
@^minimal
@core
vim
vsftpd
chrony
kexec-tools
ipa-server
bind
bind-dyndb-ldap
httpd
postfix
# unnecessary firmware
-aic94xx-firmware
-atmel-firmware
-b43-openfwwf
-bfa-firmware                                                                        
-ipw2100-firmware
-ipw2200-firmware
-ivtv-firmware
-iwl100-firmware
-iwl1000-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6050-firmware
-libertas-usb8388-firmware
-ql2100-firmware
-ql2200-firmware
-ql23xx-firmware
-ql2400-firmware
-ql2500-firmware
-rt61pci-firmware
-rt73usb-firmware
-xorg-x11-drv-ati-firmware
-zd1211-firmware
%end

################################################################################
################################################################################
##                                                                            ##
##                     PostInstall Script                                     ##
##                                                                            ##
################################################################################
################################################################################

%post --log=/root/ks-post.log

################################################################################
# Copy Packages from installation cdrom
mount /dev/cdrom /mnt
mkdir /var/ftp/repo
cp -rf /mnt/Packages/ /var/ftp/repo/Packages/
cp -rf /mnt/repodata/ /var/ftp/repo/repodata

################################################################################
# Setup RHCE Exam repository
rm -rf /etc/yum.repos.d/[a-zA-Z]*
echo '[rhce-repo]
name=rhce-repo
baseurl=file:///var/ftp/repo
gpgcheck=0' > /etc/yum.repos.d/rhce-repo.repo

################################################################################
# Setting ssh-access to the server
#       * Disable sshd naming resolution
sed -i \
    -e 's/GSSAPIAuthentication\ yes/\#GSSAPIAuthentication\ no/g' \
    -e '/#X11UseLocalhost yes/a X11UseLocalhost no' \
    /etc/ssh/sshd_config
echo " UseDNS no " >> /etc/ssh/sshd_config

################################################################################
# Setup PostFix Mail Server
postconf -e 'mynetworks = 127.0.0.0/8, 172.24.11.0/24'
postconf -e 'inet_interfaces = all'
postconf -e 'mydomain = example.com'
postconf -e 'mydestination = $myhostname, localhost.$mydomain, localhost $mydomain'
systemctl restart postfix

################################################################################
# TODO: Web interface to read the received e-mails

################################################################################
# Setup FreeIPA
echo '
ipa-server-install \
    --setup-dns \
    --realm EXAMPLE.COM \
    --ds-password ldap_password \
    --admin-password password \
    --domain example.com \
    --mkhomedir \
    --hostname rhce-ipa.example.com \
    --ip-address 172.24.11.120 \
    --no-forwarders \
    --no-host-dns \
    --unattended \
   -d 

cp /etc/ipa/ca.crt /var/ftp/pub/lab_ca.crt

echo password | kinit admin

ipa pwpolicy-mod --maxlife=9999
ipa pwpolicy-mod --minlife=0

config-mod --defaultshell=/bin/bash
echo "password" | \
    ipa user-add ldapuser1\
    --first=Ldap\
    --last=User1 \
    --password
echo "password" | \
    ipa user-add lisa \
    --first=Lisa \
    --last=Brighton \
    --password
echo "password" | \
    ipa user-add smbanonymous \
    --first=Samba \
    --last=Anonymous \
    --password

ipa host-add --ip-address 172.24.11.121 rhce-01.example.com
ipa host-add --ip-address 172.24.11.122 rhce-02.example.com

ipa service-add nfs/rhce-01.example.com
ipa service-add nfs/rhce-02.example.com

ipa-getkeytab -s rhce-ipa.example.com \
    -p  host/rhce-01.example.com \
    -k /var/ftp/pub/rhce-01.keytab
ipa-getkeytab -s rhce-ipa.example.com \
    -p host/rhce-02.example.com \
    -k /var/ftp/pub/rhce-02.keytab
ipa-getkeytab -s rhce-ipa.example.com \
    -p  nfs/rhce-01.example.com \
    -k /var/ftp/pub/rhce-01.keytab
chmod 644 /var/ftp/pub/[a-zA-Z]*.keytab

ipa dnsrecord-add example.com. @ --mx-rec="10 rhce-ipa"

ipa dnsrecord-add example.com protected --cname-rec rhce-01
ipa dnsrecord-add example.com virtual --cname-rec rhce-01
ipa dnsrecord-add example.com logic --cname-rec rhce-01
ipa dnsrecord-add example.com sales --cname-rec rhce-01
ipa host-add protected.example.com
ipa service-add HTTP/protected.example.com
ipa service-add-host --hosts=rhce-ipa.example.com HTTP/protected.example.com
ipa-getcert request -r \
    -f /etc/pki/tls/certs/protected.example.com.crt \
    -k /etc/pki/tls/private/protected.example.com.key \
    -N CN=protected.example.com \
    -D protected.example.com \
    -K HTTP/protected.example.com
sleep 10
cp /etc/pki/tls/certs/protected.example.com.crt /etc/pki/tls/private/protected.example.com.key /var/ftp/pub
' > /root/setup-ipa.sh

%end
