#!/bin/bash

# TODO 2.1: 
# PCA9685 in devicetree
# Make redeem dependencies built into redeem

# TODO 2.0:
# Custom uboot

# STAGING: 
# redeem starts after spidev2.1
#  fatal error: yaml.h: No such file or directory
# Adafruit lib disregard overlay (Swithed to spidev)
# redeem plugin
# Toggle plugin

# DONE: 
# consoleblank=0
# sgx-install after changing kernel


echo "**Making Kamikaze 2.0.4**"

export LC_ALL=C

add_testing_branch() {
    cat >/etc/apt/sources.list.d/testing.list <<EOL
#### testing/Stretch  #########
deb http://httpredir.debian.org/debian/ testing main contrib non-free
deb-src http://httpredir.debian.org/debian/ testing main contrib non-free
EOL

}

stop_services() {
	systemctl disable apache2
	systemctl stop apache2
	systemctl disable bonescript-autorun.service
	systemctl stop bonescript-autorun.service
	systemctl disable bonescript.socket
	systemctl stop bonescript.socket
	systemctl disable bonescript.service
	systemctl stop bonescript.service
}

install_dependencies_src(){
	apt-get update --fix-missing
	apt-get upgrade -y
	apt-get install -y \
	swig \
	cura-engine \
	iptables-persistent \
	socat \
	ti-sgx-es8-modules-4.4.20-bone13 \
	gnome-common gtk-doc-tools \
	gobject-introspection \
	python-gobject \
	libgirepository1.0-dev \
	python-cairo \
	libgdk-pixbuf2.0-dev \
	libgles2-mesa-dev \
	libcairo2-dev \
	libpangocairo-1.0-0 \
	libpango1.0-dev \
	libatk1.0-dev \
	libjson-glib-dev \
	libgudev-1.0-dev \
	libevdev-dev \
	libxkbcommon-dev \
	gir1.2-gtk-3.0 \
	libgtk-3-0 \
	libyaml-dev \
	libmtdev-dev 
	apt-get install -y -t testing python-scipy
	apt-get install -y -t testing python-gi-cairo
	pip install evdev
	pip install spidev
}

install_dependencies(){
	apt-get update --fix-missing
	apt-get upgrade -y
	apt-get install -y \
	swig \
	cura-engine \
	iptables-persistent \
	socat \
	ti-sgx-es8-modules-4.4.20-bone13 \
	libyaml-dev 
	apt-get install -y -t testing python-scipy
	apt-get install -y -t testing python-gi-cairo
	pip install evdev
	pip install spidev


}

install_redeem() {
	cd /usr/src/
	git clone https://bitbucket.org/intelligentagent/redeem
	cd redeem
	git checkout develop
	make install
}

post_redeem() {
	cd /usr/src/redeem
	# Make profiles uploadable via Octoprint
	mkdir -p /etc/redeem
	cp configs/*.cfg /etc/redeem/
	cp data/*.cht /etc/redeem/
	touch /etc/redeem/local.cfg
	chown -R octo:octo /etc/redeem/

	cd /usr/src/Kamikaze2

	# Install rules
	cp scripts/spidev.rules /etc/udev/rules.d/

	# Install Kamikaze2 specific systemd script
	cp scripts/redeem.service /lib/systemd/system
	systemctl enable redeem
	systemctl start redeem
}

create_user() {
	default_groups="admin,adm,dialout,i2c,kmem,spi,cdrom,floppy,audio,dip,video,netdev,plugdev,users,systemd-journal,tisdk,weston-launch,xenomai"
	mkdir /home/octo/
	mkdir /home/octo/.octoprint
	useradd -G "${default_groups}" -s /bin/bash -m -p octo -c "OctoPrint" octo
	chown -R octo:octo /home/octo
	chown -R octo:octo /usr/local/lib/python2.7/dist-packages
	chown -R octo:octo /usr/local/bin
	chmod 755 -R /usr/local/lib/python2.7/dist-packages
}

install_octoprint() {
	cd /home/octo
	su - octo -c 'git clone https://github.com/foosel/OctoPrint.git'
	su - octo -c 'cd OctoPrint && python setup.py clean install'
}

post_octoprint() {
	cd /usr/src/Kamikaze2
	# Make config file for Octoprint
	cp OctoPrint/config.yaml /home/octo/.octoprint/
	chown octo:octo "/home/octo/.octoprint/config.yaml"

	# Fix permissions for STL upload folder
	mkdir -p /usr/share/models
	chown octo:octo /usr/share/models
	chmod 777 /usr/share/models

	# Grant octo redeem restart rights
	echo "%octo ALL=NOPASSWD: /bin/systemctl restart redeem.service" >> /etc/sudoers
	echo "%octo ALL=NOPASSWD: /bin/systemctl restart toggle.service" >> /etc/sudoers

	# Port forwarding
	/sbin/iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 5000
	/usr/sbin/netfilter-persistent save

	# Install systemd script
	cp ./OctoPrint/octoprint.service /lib/systemd/system/
	systemctl enable octoprint
	systemctl start octoprint
}

install_octoprint_redeem() {
	echo "**install_octoprint_redeem**" 
	cd /usr/src/
	if [ ! -d "octoprint_redeem" ]; then
		git clone https://github.com/eliasbakken/octoprint_redeem
	fi
	cd octoprint_redeem
	python setup.py install
}

install_octoprint_toggle() {
	echo "**install_octoprint_toggle**" 
	cd /usr/src
	if [ ! -d "octoprint_toggle" ]; then
		git clone https://github.com/eliasbakken/octoprint_toggle
	fi
	cd octoprint_toggle
	python setup.py install
}

install_overlays() {
	echo "**install_overlays**" 
	cd /usr/src/
	if [ ! -d "bb.org-overlays" ]; then
		git clone https://github.com/eliasbakken/bb.org-overlays
	fi
	cd bb.org-overlays
	./install.sh 
}

install_sgx() {
	cd /usr/src/Kamikaze2
	tar xfv GFX_5.01.01.02_es8.x.tar.gz -C /
	cd /opt/gfxinstall/
	./sgx-install.sh
	cd /usr/src/Kamikaze2/
	cp scripts/sgx-startup.service /lib/systemd/system/
	systemctl enable sgx-startup.service
	depmod -a 4.4.20-bone13
}

install_cogl_src() {
	cd /usr/src
	apt-get build-dep -y -t testing cogl
	apt-get source -y -t testing cogl
	cd cogl-1.22.2/
	./configure --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ --enable-introspection --disable-gles1 --enable-cairo --disable-gl --enable-gles2 --enable-null-egl-platform --enable-cogl-pango
	sed -i 's/#if COGL_HAS_WAYLAND_EGL_SERVER_SUPPORT/#ifdef COGL_HAS_WAYLAND_EGL_SERVER_SUPPORT/' cogl/winsys/cogl-winsys-egl.c 
	make
	make install
}

install_cogl() {
	apt-get install libcogl20
}



install_clutter_src() {
	cd /usr/src
	apt-get build-dep -y -t testing clutter-1.0
	apt-get source -y -t testing clutter-1.0
	cd clutter-1.0-1.26.0
	./configure --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ --disable-x11-backend  --enable-egl-backend --enable-evdev-input --disable-gdk-backend --disable-wayland-backend
	make
	make install
}

install_clutter() {
	apt-get install -t testing libclutter-1.0-0
}

install_mx() {
	cd /usr/src
	git clone https://github.com/clutter-project/mx.git
	cd mx
	./autogen.sh --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ --with-winsys=none --disable-gtk-doc --enable-introspection
	make
	make install
}

install_mash() {
	cd /usr/src
	git clone https://github.com/eliasbakken/mash.git
	cd /usr/src/mash
	./autogen.sh --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ --enable-introspection
	sed -i 's:--library=mash-@MASH_API_VERSION@:--library=mash-@MASH_API_VERSION@ \ --library-path=/usr/src/mash/mash/.libs/:' mash/Makefile.am
	make CFLAGS="`pkg-config --cflags clutter-1.0`"
	make install
}

install_toggle() {
	cd /usr/src
	git clone https://bitbucket.org/intelligentagent/toggle
	cd toggle
	make install
}

post_toggle() {
	cd /usr/src/toggle
	cp systemd/toggle.service /lib/systemd/system/
	systemctl enable toggle
	systemctl start toggle
}

post_cura() {
	# Copy profiles into Cura.
	cd /usr/src/Kamikaze2
	mkdir -p /home/octo/.octoprint/slicingProfiles/cura/
	cp ./Cura/profiles/*.profile /home/octo/.octoprint/slicingProfiles/cura/
	chown octo:octo /home/octo/.octoprint/slicingProfiles/cura/
}


install_uboot() {
	cd /usr/src/Kamikaze2
	export DISK=/dev/mmcblk0
	dd if=./u-boot/MLO of=${DISK} count=1 seek=1 bs=128k
	dd if=./u-boot/u-boot.img of=${DISK} count=2 seek=1 bs=384k
}

other() {
	sed -i 's/cape_universal=enable/consoleblank=0 fbcon=rotate:1 omap_wdt.nowayout=0/' /boot/uEnv.txt	
	sed -i 's/beaglebone/kamikaze/' /etc/hostname
	# TODO: sudo: unable to resolve host kamikaze
}


all() {
	add_testing_branch
	stop_services
	install_dependencies
	install_redeem
	post_redeem
	create_user
	install_octoprint
	post_octoprint
	install_octoprint_redeem
	install_octoprint_toggle
	install_overlays
	install_sgx
	install_cogl
	install_clutter
	install_mx
	install_mash
	install_toggle
	post_toggle
	post_cura
	install_uboot
	other
}

all

echo "Now reboot!"

