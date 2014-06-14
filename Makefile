RELEASE=3.2

KERNEL_VER=3.10.0
PKGREL=11
# also include firmware of previous versrion into 
# the fw package:  fwlist-2.6.32-PREV-pve
KREL=3

RHKVER=123.el7

KERNELSRCRPM=kernel-${KERNEL_VER}-${RHKVER}.src.rpm

ARCH=amd64

EXTRAVERSION=-${KREL}-${ARCH}
KVNAME=${KERNEL_VER}${EXTRAVERSION}
PACKAGE=linux-image-${KVNAME}
HDRPACKAGE=linux-headers-${KVNAME}

GITVERSION:=$(shell cat .git/refs/heads/master)

TOP=$(shell pwd)

KERNEL_SRC=linux-2.6-${KERNEL_VER}
RHKERSRCDIR=rh-kernel-src
KERNEL_CFG=config-${KERNEL_VER}

KERNEL_CFG_ORG=${RHKERSRCDIR}/kernel-${KERNEL_VER}-x86_64.config

FW_VER=1.1
FW_REL=2
FW_DEB=ffzg-firmware_${FW_VER}-${FW_REL}_all.deb

DRBDDIR=drbd-8.4.5
DRBDSRC=${DRBDDIR}.tar.gz

E1000EDIR=e1000e-3.0.4.1
E1000ESRC=${E1000EDIR}.tar.gz

IGBDIR=igb-5.2.5
IGBSRC=${IGBDIR}.tar.gz

IXGBEDIR=ixgbe-3.19.1
IXGBESRC=${IXGBEDIR}.tar.gz

# this does not compile correctly
BNX2DIR=netxtreme2-7.8.56
BNX2SRC=${BNX2DIR}.tar.gz

AACRAIDVER=1.2.1-40300
AACRAIDDIR=aacraid-${AACRAIDVER}.src
AACRAIDSRC=aacraid-linux-src-${AACRAIDVER}.tgz

# kernel contains newer version 06.700.06.00-rc1
#MEGARAID_DIR=megaraid_sas-06.600.18.00
#MEGARAID_SRC=${MEGARAID_DIR}-src.tar.gz

ARECADIR=arcmsr-1.30.0X.16-20131206
ARECASRC=${ARECADIR}.zip

# this one does not compile with newer 3.10 kernels!
#RR272XSRC=RR272x_1x-Linux-Src-v1.5-130325-0732.tar.gz
#RR272XDIR=rr272x_1x-linux-src-v1.5

# this project look dead - no updates since 3 years
#ISCSITARGETDIR=iscsitarget-1.4.20.2
#ISCSITARGETSRC=${ISCSITARGETDIR}.tar.gz

DST_DEB=${PACKAGE}_${KERNEL_VER}-${PKGREL}_${ARCH}.deb
HDR_DEB=${HDRPACKAGE}_${KERNEL_VER}-${PKGREL}_${ARCH}.deb
PVEPKG=ffzg-ganeti-${KERNEL_VER}
PVE_DEB=${PVEPKG}_${RELEASE}-${PKGREL}_all.deb

all: check_gcc ${DST_DEB} ${FW_DEB} ${HDR_DEB}

check_gcc: 
	gcc --version|grep "4\.7\.2" || false

${DST_DEB}: data control.in postinst.in copyright changelog.Debian
	mkdir -p data/DEBIAN
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@KVNAME@/${KVNAME}/' -e 's/@PKGREL@/${PKGREL}/' <control.in >data/DEBIAN/control
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <postinst.in >data/DEBIAN/postinst
	chmod 0755 data/DEBIAN/postinst
	install -D -m 644 copyright data/usr/share/doc/${PACKAGE}/copyright
	install -D -m 644 changelog.Debian data/usr/share/doc/${PACKAGE}/changelog.Debian
	echo "git clone https://github.com/ffzg/ffzg-kernel-3.10.git\\ngit checkout ${GITVERSION}" > data/usr/share/doc/${PACKAGE}/SOURCE
	gzip -f --best data/usr/share/doc/${PACKAGE}/changelog.Debian
	rm -f data/lib/modules/${KVNAME}/source
	rm -f data/lib/modules/${KVNAME}/build
	dpkg-deb --build data ${DST_DEB}
	lintian ${DST_DEB}


fwlist-${KVNAME}: data
	./find-firmware.pl data/lib/modules/${KVNAME} >fwlist.tmp
	mv fwlist.tmp $@

# fixme: bnx2.ko cnic.ko bnx2x.ko
data: .compile_mark ${KERNEL_CFG} drbd.ko e1000e.ko igb.ko ixgbe.ko aacraid.ko arcmsr.ko
	rm -rf data tmp; mkdir -p tmp/lib/modules/${KVNAME}
	mkdir tmp/boot
	install -m 644 ${KERNEL_CFG} tmp/boot/config-${KVNAME}
	install -m 644 ${KERNEL_SRC}/System.map tmp/boot/System.map-${KVNAME}
	install -m 644 ${KERNEL_SRC}/arch/x86_64/boot/bzImage tmp/boot/vmlinuz-${KVNAME}
	cd ${KERNEL_SRC}; make INSTALL_MOD_PATH=../tmp/ modules_install
	# install latest drbd driver
	install -m 644 drbd.ko tmp/lib/modules/${KVNAME}/kernel/drivers/block/drbd/
	# install latest ixgbe driver
	install -m 644 ixgbe.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/ixgbe/
	# install latest e1000e driver
	install -m 644 e1000e.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/e1000e/
	# install latest ibg driver
	install -m 644 igb.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/intel/igb/
	## install bnx2 drivers
	#install -m 644 bnx2.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/broadcom/
	#install -m 644 cnic.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/broadcom/
	#install -m 644 bnx2x.ko tmp/lib/modules/${KVNAME}/kernel/drivers/net/ethernet/broadcom/bnx2x/
	# install aacraid drivers
	install -m 644 aacraid.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/aacraid/
	## install Highpoint 2710 RAID driver
	#install -m 644 rr272x_1x.ko -D tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/rr272x_1x/rr272x_1x.ko
	# install areca driver
	install -m 644 arcmsr.ko tmp/lib/modules/${KVNAME}/kernel/drivers/scsi/arcmsr/
	# remove firmware
	rm -rf tmp/lib/firmware
	# strip debug info
	find tmp/lib/modules -name \*.ko -print | while read f ; do strip --strip-debug "$$f"; done
	# finalize
	depmod -b tmp/ ${KVNAME}
	mv tmp data

.compile_mark: ${KERNEL_SRC}/README ${KERNEL_CFG}
	cp ${KERNEL_CFG} ${KERNEL_SRC}/.config
	cd ${KERNEL_SRC}; make oldconfig
	cd ${KERNEL_SRC}; make -j 8
	touch $@

${KERNEL_CFG}: ${KERNEL_CFG_ORG} config-${KERNEL_VER}.diff
	cp ${KERNEL_CFG_ORG} ${KERNEL_CFG}.new
	patch --no-backup ${KERNEL_CFG}.new config-${KERNEL_VER}.diff
	mv ${KERNEL_CFG}.new ${KERNEL_CFG}

${KERNEL_SRC}/README: ${KERNEL_SRC}.org/README
	rm -rf ${KERNEL_SRC}
	cp -a ${KERNEL_SRC}.org ${KERNEL_SRC}
	#cd ${KERNEL_SRC}; patch -p1 <../bootsplash-3.8.diff
	#cd ${KERNEL_SRC}; patch -p1 <../${RHKERSRCDIR}/patch-042stab083
	#cd ${KERNEL_SRC}; patch -p1 <../do-not-use-barrier-on-ext3.patch
	cd ${KERNEL_SRC}; patch -p1 <../bridge-patch.diff
	#cd ${KERNEL_SRC}; patch -p1 <../kvm-fix-invalid-secondary-exec-controls.patch
	#cd ${KERNEL_SRC}; patch -p1 <../fix-aspm-policy.patch
	#cd ${KERNEL_SRC}; patch -p1 <../kbuild-generate-mudules-builtin.patch
	#cd ${KERNEL_SRC}; patch -p1 <../add-tiocgdev-ioctl.patch
	#cd ${KERNEL_SRC}; patch -p1 <../fix-nfs-block-count.patch
	#cd ${KERNEL_SRC}; patch -p1 <../fix-idr-header-for-drbd-compilation.patch
	cd ${KERNEL_SRC}; patch -p1 <../n_tty-Fix-n_tty_write-crash-when-echoing-in-raw-mode.patch
	sed -i ${KERNEL_SRC}/Makefile -e 's/^EXTRAVERSION.*$$/EXTRAVERSION=${EXTRAVERSION}/'
	touch $@

${KERNEL_SRC}.org/README: ${RHKERSRCDIR}/kernel.spec ${RHKERSRCDIR}/linux-${KERNEL_VER}-${RHKVER}.tar.xz
	rm -rf ${KERNEL_SRC}.org linux-${KERNEL_VER}-${RHKVER}
	tar xf ${RHKERSRCDIR}/linux-${KERNEL_VER}-${RHKVER}.tar.xz
	mv linux-${KERNEL_VER}-${RHKVER} ${KERNEL_SRC}.org
	touch $@

${RHKERSRCDIR}/kernel.spec: ${KERNELSRCRPM}
	rm -rf ${RHKERSRCDIR}
	mkdir ${RHKERSRCDIR}
	cd ${RHKERSRCDIR};rpm2cpio ../${KERNELSRCRPM} |cpio -i
	touch $@

#rr272x_1x.ko: .compile_mark ${RR272XSRC}
#	rm -rf ${RR272XDIR}
#	tar xf ${RR272XSRC}
#	mkdir -p /lib/modules/${KVNAME}
#	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
#	make -C ${TOP}/${RR272XDIR}/product/rr272x/linux KERNELDIR=${TOP}/${KERNEL_SRC}
#	cp ${RR272XDIR}/product/rr272x/linux/$@ .


drbd.ko drbd: .compile_mark ${DRBDSRC}
	rm -rf ${DRBDDIR}
	tar xvf ${DRBDSRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${DRBDDIR}; make KDIR=${TOP}/${KERNEL_SRC}
	cp ${DRBDDIR}/drbd/drbd.ko drbd.ko
	
aacraid.ko: .compile_mark ${AACRAIDSRC}
	rm -rf ${AACRAIDDIR}
	tar xzf ${AACRAIDSRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	make -C ${TOP}/${KERNEL_SRC} M=${TOP}/${AACRAIDDIR}/aacraid_source modules
	cp ${AACRAIDDIR}/aacraid_source/aacraid.ko .

e1000e.ko e1000e: .compile_mark ${E1000ESRC}
	rm -rf ${E1000EDIR}
	tar xf ${E1000ESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${E1000EDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${E1000EDIR}/src/e1000e.ko e1000e.ko

igb.ko igb: .compile_mark ${IGBSRC}
	rm -rf ${IGBDIR}
	tar xf ${IGBSRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${IGBDIR}/src; make BUILD_KERNEL=${KVNAME}
	cp ${IGBDIR}/src/igb.ko igb.ko

ixgbe.ko ixgbe: .compile_mark ${IXGBESRC}
	rm -rf ${IXGBEDIR}
	tar xf ${IXGBESRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${IXGBEDIR}/src; make CFLAGS_EXTRA="-DIXGBE_NO_LRO" BUILD_KERNEL=${KVNAME}
	cp ${IXGBEDIR}/src/ixgbe.ko ixgbe.ko

bnx2.ko cnic.ko bnx2x.ko: ${BNX2SRC}
	rm -rf ${BNX2DIR}
	tar xf ${BNX2SRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${BNX2DIR}; make -C bnx2/src KVER=${KVNAME}
	cd ${BNX2DIR}; make -C bnx2x/src KVER=${KVNAME}
	cp `find ${BNX2DIR} -name bnx2.ko -o -name cnic.ko -o -name bnx2x.ko` .

arcmsr.ko: .compile_mark ${ARECASRC}
	rm -rf ${ARECADIR}
	mkdir ${ARECADIR}; cd ${ARECADIR}; unzip ../${ARECASRC}
	mkdir -p /lib/modules/${KVNAME}
	ln -sf ${TOP}/${KERNEL_SRC} /lib/modules/${KVNAME}/build
	cd ${ARECADIR}; make -C ${TOP}/${KERNEL_SRC} SUBDIRS=${TOP}/${ARECADIR} modules
	cp ${ARECADIR}/arcmsr.ko arcmsr.ko

#iscsi_trgt.ko: .compile_mark ${ISCSITARGETSRC}
#	rm -rf ${ISCSITARGETDIR}
#	tar xf ${ISCSITARGETSRC}
#	cd ${ISCSITARGETDIR}; make KSRC=${TOP}/${KERNEL_SRC}
#	cp ${ISCSITARGETDIR}/kernel/iscsi_trgt.ko iscsi_trgt.ko

headers_tmp := $(CURDIR)/tmp-headers
headers_dir := $(headers_tmp)/usr/src/linux-headers-${KVNAME}

${HDR_DEB} hdr: .compile_mark headers-control.in headers-postinst.in
	rm -rf $(headers_tmp)
	install -d $(headers_tmp)/DEBIAN $(headers_dir)/include/
	sed -e 's/@KERNEL_VER@/${KERNEL_VER}/' -e 's/@KVNAME@/${KVNAME}/' -e 's/@PKGREL@/${PKGREL}/' <headers-control.in >$(headers_tmp)/DEBIAN/control
	sed -e 's/@@KVNAME@@/${KVNAME}/g'  <headers-postinst.in >$(headers_tmp)/DEBIAN/postinst
	chmod 0755 $(headers_tmp)/DEBIAN/postinst
	install -D -m 644 copyright $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/copyright
	install -D -m 644 changelog.Debian $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/changelog.Debian
	echo "git clone https://github.com/ffzg/ffzg-kernel-3.10.git\\ngit checkout ${GITVERSION}" > $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/SOURCE
	gzip -f --best $(headers_tmp)/usr/share/doc/${HDRPACKAGE}/changelog.Debian
	install -m 0644 ${KERNEL_SRC}/.config $(headers_dir)
	install -m 0644 ${KERNEL_SRC}/Module.symvers $(headers_dir)
	cd ${KERNEL_SRC}; find . -path './debian/*' -prune -o -path './include/*' -prune -o -path './Documentation' -prune \
	  -o -path './scripts' -prune -o -type f \
	  \( -name 'Makefile*' -o -name 'Kconfig*' -o -name 'Kbuild*' -o \
	     -name '*.sh' -o -name '*.pl' \) \
	  -print | cpio -pd --preserve-modification-time $(headers_dir)
	cd ${KERNEL_SRC}; cp -a include scripts $(headers_dir)
	cd ${KERNEL_SRC}; (find arch/x86 -name include -type d -print | \
		xargs -n1 -i: find : -type f) | \
		cpio -pd --preserve-modification-time $(headers_dir)
	dpkg-deb --build $(headers_tmp) ${HDR_DEB}
	#lintian ${HDR_DEB}

dvb-firmware.git/README:
	git clone https://github.com/OpenELEC/dvb-firmware.git dvb-firmware.git

linux-firmware.git/WHENCE:
	git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git linux-firmware.git

${FW_DEB} fw: control.firmware linux-firmware.git/WHENCE dvb-firmware.git/README changelog.firmware fwlist-2.6.18-2-pve fwlist-2.6.24-12-pve fwlist-2.6.32-3-pve fwlist-2.6.32-4-pve fwlist-2.6.32-6-pve fwlist-2.6.35-1-pve fwlist-2.6.32-13-pve fwlist-2.6.32-14-pve fwlist-2.6.32-20-pve fwlist-2.6.32-21-pve fwlist-${KVNAME}
	rm -rf fwdata
	mkdir -p fwdata/lib/firmware
	./assemble-firmware.pl fwlist-${KVNAME} fwdata/lib/firmware
	# include any files from older/newer kernels here
	./assemble-firmware.pl fwlist-2.6.24-12-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.18-2-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-3-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-4-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-6-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.35-1-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-13-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-14-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-20-pve fwdata/lib/firmware
	./assemble-firmware.pl fwlist-2.6.32-21-pve fwdata/lib/firmware
	install -d fwdata/usr/share/doc/pve-firmware
	cp linux-firmware.git/WHENCE fwdata/usr/share/doc/pve-firmware/README
	install -d fwdata/usr/share/doc/pve-firmware/licenses
	cp linux-firmware.git/LICEN[CS]E* fwdata/usr/share/doc/pve-firmware/licenses
	install -D -m 0644 changelog.firmware fwdata/usr/share/doc/pve-firmware/changelog.Debian
	gzip -9 fwdata/usr/share/doc/pve-firmware/changelog.Debian
	echo "git clone https://github.com/ffzg/ffzg-kernel-3.10.git\\ngit checkout ${GITVERSION}" >fwdata/usr/share/doc/pve-firmware/SOURCE
	install -d fwdata/DEBIAN
	sed -e 's/@VERSION@/${FW_VER}-${FW_REL}/' <control.firmware >fwdata/DEBIAN/control
	dpkg-deb --build fwdata ${FW_DEB}

.PHONY: upload
upload: ${DST_DEB} ${HDR_DEB} ${FW_DEB}
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o rw 
	mkdir -p /pve/${RELEASE}/extra
	mkdir -p /pve/${RELEASE}/install
	rm -rf /pve/${RELEASE}/extra/${PACKAGE}_*.deb
	rm -rf /pve/${RELEASE}/extra/${HDRPACKAGE}_*.deb
	rm -rf /pve/${RELEASE}/extra/pve-firmware*.deb
	rm -rf /pve/${RELEASE}/extra/Packages*
	cp ${DST_DEB} ${FW_DEB} ${HDR_DEB} /pve/${RELEASE}/extra
	cd /pve/${RELEASE}/extra; dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz
	umount /pve/${RELEASE}; mount /pve/${RELEASE} -o ro

.PHONY: distclean
distclean: clean
	rm -rf linux-firmware.git dvb-firmware.git ${KERNEL_SRC}.org ${RHKERSRCDIR}

.PHONY: clean
clean:
	rm -rf *~ .compile_mark ${KERNEL_CFG} ${KERNEL_SRC} tmp data proxmox-ve/data *.deb ${AOEDIR} aoe.ko drbd.ko ${DRBDDIR} ${headers_tmp} fwdata fwlist.tmp *.ko ${IXGBEDIR} ${E1000EDIR} e1000e.ko ${IGBDIR} igb.ko fwlist-${KVNAME} ${BNX2DIR} bnx2.ko cnic.ko bnx2x.ko aacraid.ko ${AACRAIDDIR} rr272x_1x.ko ${RR272XDIR} ${ARECADIR}.ko ${ARECADIR}




