# https://docs.frrouting.org/projects/dev-guide/en/latest/building-frr-for-freebsd14.html

pkg install -fy automake
pkg install -fy bison
pkg install -fy c-ares
pkg install -fy git
pkg install -fy gmake
pkg install -fy json-c
pkg install -fy libtool
pkg install -fy libunwind
pkg install -fy libyang2
pkg install -fy pkgconf
pkg install -fy protobuf-c
pkg install -fy py311-pytest
pkg install -fy py311-sphinx
pkg install -fy texinfo

pw groupadd frr -g 101
pw groupadd frrvty -g 102
pw adduser frr -g 101 -u 101 -G 102 -c "FRR suite" -d /usr/local/etc/frr -s /usr/sbin/nologin

git clone https://github.com/frrouting/frr.git frr
cd frr
./bootstrap.sh
export MAKE=gmake LDFLAGS=-L/usr/local/lib CPPFLAGS=-I/usr/local/include
./configure \
    --sysconfdir=/usr/local/etc \
    --localstatedir=/var \
    --enable-pkgsrcrcdir=/usr/pkg/share/examples/rc.d \
    --prefix=/usr/local \
    --enable-multipath=64 \
    --enable-user=frr \
    --enable-group=frr \
    --enable-vty-group=frrvty \
    --enable-configfile-mask=0640 \
    --enable-logfile-mask=0640 \
    --enable-fpm \
    --with-pkg-git-version \
    --with-pkg-extra-version=-MyOwnFRRVersion
gmake
gmake check
sudo gmake install

mkdir /usr/local/etc/frr
touch /usr/local/etc/frr/frr.conf

sudo touch /usr/local/etc/frr/babeld.conf
sudo touch /usr/local/etc/frr/bfdd.conf
sudo touch /usr/local/etc/frr/bgpd.conf
sudo touch /usr/local/etc/frr/eigrpd.conf
sudo touch /usr/local/etc/frr/isisd.conf
sudo touch /usr/local/etc/frr/ldpd.conf
sudo touch /usr/local/etc/frr/nhrpd.conf
sudo touch /usr/local/etc/frr/ospf6d.conf
sudo touch /usr/local/etc/frr/ospfd.conf
sudo touch /usr/local/etc/frr/pbrd.conf
sudo touch /usr/local/etc/frr/pimd.conf
sudo touch /usr/local/etc/frr/ripd.conf
sudo touch /usr/local/etc/frr/ripngd.conf
sudo touch /usr/local/etc/frr/staticd.conf
sudo touch /usr/local/etc/frr/zebra.conf
sudo chown -R frr:frr /usr/local/etc/frr/
sudo touch /usr/local/etc/frr/vtysh.conf
sudo chown frr:frrvty /usr/local/etc/frr/vtysh.conf
sudo chmod 640 /usr/local/etc/frr/*.conf

echo "net.inet.ip.forwarding=1" | sudo tee -a /etc/sysctl.conf
echo "net.inet6.ip6.forwarding=1" | sudo tee -a /etc/sysctl.conf
sysctl net.inet.ip.forwarding=1
sysctl net.inet6.ip6.forwarding=1

reboot
