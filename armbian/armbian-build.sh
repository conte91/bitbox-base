#!/bin/bash

# BitBoxBase: build Armbian base image
#
# Script to automate the build process of the customized Armbian base image for the BitBoxBase.
# Additional information: https://digitalbitbox.github.io/bitbox-base
#
set -eu

function usage() {
	echo "Build customized Armbian base image for BitBoxBase"
	echo "Usage: ${0} [build|update|ondevice]"
	echo
	echo "running the setup directly ondevice currently support"
	echo "Armbian releases Debian Buster and Ubuntu Bionic"
}

ACTION=${1:-"build"}

if ! [[ "${ACTION}" =~ ^(build|update|ondevice)$ ]]; then
	usage
	exit 1
fi

case ${ACTION} in
	build|update)
		if ! command -v git >/dev/null 2>&1 || ! command -v docker >/dev/null 2>&1; then
			echo
			echo "Build environment not set up, please check documentation at"
			echo "https://digitalbitbox.github.io/bitbox-base"
			echo
			exit 1
		fi

		git log --pretty=format:'%h' -n 1 > ./base/config/latest_commit

		if [ ! -d "armbian-build" ]; then
			git clone https://github.com/armbian/build armbian-build
		fi

		mkdir -p armbian-build/output/
		mkdir -p armbian-build/userpatches/overlay/bin/go
		cp -a  base/customize-image.sh armbian-build/userpatches/		# copy customize script to standard Armbian build hook
		cp -aR base/* armbian-build/userpatches/overlay/					# copy scripts and configuration items to overlay
		cp -aR ../bin/go/* armbian-build/userpatches/overlay/bin/go			# copy additional software binaries to overlay

		BOARD=${BOARD:-rockpro64}
		BUILD_ARGS="docker BOARD=${BOARD} KERNEL_ONLY=no KERNEL_CONFIGURE=no BUILD_MINIMAL=yes BUILD_DESKTOP=no RELEASE=bionic BRANCH=default WIREGUARD=no PROGRESS_LOG_TO_FILE=yes"
		if [ "${ACTION}" == "update" ]; then
			BUILD_ARGS="${BUILD_ARGS} CLEAN_LEVEL=oldcache"
		fi
		# shellcheck disable=SC2086
		time armbian-build/compile.sh ${BUILD_ARGS}

		# move compiled Armbian image to binaries directory
		IMG_COUNT=$(find armbian-build/output/images/Armbian_*.img | grep -c ^armbian)

		if [[ ${IMG_COUNT} -eq 1 ]]; then
			mv -v armbian-build/output/images/Armbian_*.img ../bin/img-armbian/BitBoxBase_Armbian_RockPro64.img
		else
			echo "ERR: one image file expected in armbian-build/output/images/, ${IMG_COUNT} files found."
			find armbian-build/output/images/Armbian_*.img
			exit 1
		fi
		;;

	ondevice)
    	# copy custom scripts to filesystem
    	mkdir -p /opt/shift
    	cp -aR base/* /opt/shift
    	chmod -R +x /opt/shift/scripts

		# run customization script
		base/customize-armbian-rockpro64.sh ondevice
esac
