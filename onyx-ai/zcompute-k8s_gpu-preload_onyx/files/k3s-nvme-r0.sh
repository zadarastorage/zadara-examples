#!/usr/bin/env bash
# k3s-nvme-r0.sh
# Idempotent RAID0 setup for one or more NVMe devices
# - Always creates RAID0 (even with 1 device)
# - No partitions, no fstab, no symlinks
# - Does not overwrite or reinitialize if md0 already exists

set -euo pipefail
_log() { echo "[$0] ${@}"; }
_log "Starting RAID0 NVMe provisioning"

########################################
# 1. Detect all NVMe disks
########################################
NVME_DEVS=($(lsblk -dno NAME,TYPE | awk '$2=="disk" && $1 ~ /^nvme/ {print "/dev/" $1}'))
NUM_DEVS=${#NVME_DEVS[@]}

if [[ $NUM_DEVS -eq 0 ]]; then
  _log "No NVMe devices found. Exiting."
  exit 0
fi

_log "Detected NVMe devices: ${NVME_DEVS[*]}"

MD_DEV="/dev/md0"
MOUNT_POINT="/mnt/ephemeral0"

########################################
# 2. If RAID already exists and is active, skip creation
########################################
if [[ -b "$MD_DEV" ]] && grep -q "$MD_DEV" /proc/mdstat; then
  _log "RAID device $MD_DEV already exists."
else
  _log "Creating new RAID0 array on ${NUM_DEVS} device(s)"

  # Zero superblocks first — safe only because md0 does not exist yet
  for dev in "${NVME_DEVS[@]}"; do
    mdadm --zero-superblock --force "$dev" || true
  done

  mdadm --create --verbose "$MD_DEV" \
    --level=0 \
    --force \
    --raid-devices=$NUM_DEVS \
    "${NVME_DEVS[@]}"

  udevadm settle
  sleep 2
fi

########################################
# 3. Format md0 if not already
########################################
if ! blkid "$MD_DEV" &>/dev/null; then
  _log "Formatting $MD_DEV as ext4"
  mkfs.ext4 -F -L k3s_nvme_raid "$MD_DEV"
else
  _log "$MD_DEV already formatted."
fi

########################################
# 4. Mount it (ephemeral VM: no fstab)
########################################
mkdir -p "$MOUNT_POINT"

if ! mountpoint -q "$MOUNT_POINT"; then
  _log "Mounting $MD_DEV to $MOUNT_POINT"
  mount -o defaults,noatime,nodiratime,discard,errors=panic "$MD_DEV" "$MOUNT_POINT"
else
  _log "$MOUNT_POINT already mounted."
fi

for target in 'run/k3s' 'var/lib/rancher' 'var/lib/kubelet'; do
  if [[ ! -d "${MOUNT_POINT}/${target//\//-}" || ! -L "/${target}" ]]; then
    _log "Creating ${MOUNT_POINT}/${target//\//-}"
    mkdir -p "${MOUNT_POINT}/${target//\//-}"
    _log "Symlinking ${MOUNT_POINT}/${target//\//-} <-> /${target}"
    ln -s "${MOUNT_POINT}/${target//\//-}" "/${target}"
  fi
done

_log "Done."
