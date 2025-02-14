#!/bin/bash
[[ $(lspci -n -d '10de:' | wc -l) -eq 0 ]] && exit 0
source /etc/os-release
OS="${ID}${VERSION_ID//./}"
ARCH=$(uname -m)
# Setup cuda repository
if [[ -x $(which apt-get) ]]; then
	sudo apt-key del 7fa2af80
	wget -q -O /tmp/cuda-keyring_1.1-1_all.deb https://developer.download.nvidia.com/compute/cuda/repos/${OS}/${ARCH}/cuda-keyring_1.1-1_all.deb
	sudo dpkg -i /tmp/cuda-keyring_1.1-1_all.deb
	rm /tmp/cuda-keyring_1.1-1_all.deb
	# Setup nvidia-container-runtime repository
	curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
	  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
	    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
	    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

	apt-get update
	# Install packages
	# Proprietary
	apt-get install -o Acquire::ForceIPv4=true -qq -y cuda-drivers cuda-drivers-fabricmanager nvidia-container-runtime nvtop
fi
