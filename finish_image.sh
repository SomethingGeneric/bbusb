#!/usr/bin/env bash

set -ex

LIMINE_VER="3.20.1"

if [[ ! "$EUID" == "0" ]]; then
	echo "Run as root"
	exit 1
fi

loopdev=$(losetup -P -f --show image)

mkfs.ext4 ${loopdev}p1


[[ -d mountpt ]] && rm -rf mountpt
mkdir mountpt

mount ${loopdev}p1 mountpt

cd mountpt

mkdir -p usr/{sbin,bin} bin sbin boot
mkdir -p {dev,etc,home,lib,run,mnt,opt,proc,srv,sys}
mkdir -p var/{lib,lock,log,run,spool}
install -d -m 0750 root
install -d -m 1777 tmp
mkdir -p usr/{include,lib,share/udhcpc,src}

cp ../outputs/busybox usr/bin/busybox
cp ../outputs/bzImage boot/bzImage

for util in $(./usr/bin/busybox --list-full); do
  if [[ ! "$util" == "busybox" ]]; then
  	ln -s /usr/bin/busybox $util
  fi
done

cp -rv ../filesystem/etc/* etc/.
cp ../filesystem/usr/share/udhcpc/default.script usr/share/udhcpc/.
cp ../filesystem/boot/limine.cfg boot/.
cp ../outputs/limine.sys boot/.

cd ../

cd mountpt

partuuid=$(fdisk -l ../image | grep "Disk identifier" | awk '{split($0,a,": "); print a[2]}' | sed 's/0x//g')
sed -i "s/something/${partuuid}-01/g" boot/limine.cfg

mkdir -p boot/grub

cat > boot/grub/grub.cfg << EOF
linux /boot/bzImage root=PARTUUID=$partuuid
boot
EOF

cd ../

umount -R -l mountpt

rm -rf mountpt

losetup -D

./outputs/limine-deploy ./image
