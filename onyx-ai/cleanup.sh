#!/bin/bash
IFS=$'\n'
shopt -s extglob
## Configuration
TERRAFORM_VERSION="1.9.8"

## Functions
function _usage {
	echo "Usage: $0 <folder>"
}

function cpu_arch {
  case "${1}-$(uname -m)" in
    @(tf)-@(x86_64|amd64) )  echo "amd64" ;;
    @(tf)-@(i368|i686) )     echo "i386" ;;
    @(tf)-@(aarch64|arm64) ) echo "arm64" ;;
    @(tf)-@(armv6l|armel|armv7l|armhf) )  echo "arm" ;;
  esac
}

function terraform {
  TERRAFORM_PATH=$(which terraform || echo /tmp/terraform)
  if [ ! -x "${TERRAFORM_PATH}" ]; then
    wget --quiet https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_$(uname -s | tr '[A-Z]' '[a-z]')_$(cpu_arch tf).zip -O "${TERRAFORM_PATH}.zip"
    unzip -j "${TERRAFORM_PATH}.zip" "terraform" -d "$(dirname "${TERRAFORM_PATH}")"
    chmod +x "${TERRAFORM_BIN}"
    rm "${TERRAFORM_PATH}.zip"
  fi
  "${TERRAFORM_PATH}" "${@}"
}

## Logic
[ ${#} -ne 1 ] && _usage && exit 1
[ ${#} -eq 1 ] && [ ! -d "${1}" ] && echo "Error: '${1}' not found" && _usage && exit 1

cd "${1}"

# Not quite perfect, destroy will fail if loadbalancer-controller has successfully launched an LB.
# Probably need to run a second time after manually destroying the LB
for x in 'destroy'; do
	echo "== terraform ${x}"
	terraform ${x}
	RES=$?
	[ $RES -ne 0 ] && echo "Error: 'terraform ${x}' returned ${RES}" && exit 1
done
