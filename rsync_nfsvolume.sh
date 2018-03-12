#!/bin/bash
######################################
# ARGS: start : Start shell
# Useage: sync_nfsvolume.sh start

######################################
# Set VARs
 # Backup disk
dest_dsk="/dev/disk/by-id/ata-WDC_WD30EFRX-68EUZN0_WD-WCC4NxxxxxxZ-part1"
 # Data disk that mounted for NFS
src_dsk="/dev/disk/by-id/ata-WDC_WD30EFRX-68EUZN0_WD-WCC4Nxxxxxx7-part1"
 # NFS directory
nfsvol="/nfsvolume01"
 # for Backup direstory
dst="/dest_sync"
 # NFS sub directory
parh_subdir="share"
 # date
date_v=`date +"%Y%m%d_%H%M%S"`
 # log for xfs_repair
xfs_repair_log="/var/tmp/${date_v}_xfs_repair_n.log"

#######################################
# Function: abort
function abort(){
  echo "$@" >2&
  exit 1
}

#######################################
# Function: file_exists
function file_exists(){
  for i in $@
  do
    if [ ! -e $i ];then
      ls -ld $i
      exit 1
    fi
  done
  return 0
}

#######################################
# Function: is_vars_defined
function is_vars_defined(){
  local var1=$1

  if [ -z "${var1}" ] && [ "{$var1:-A}" == "{$var1-A}" ]; then
    return 1
  fi
  if [ -z ${var1} ]; then 
    return 1
  fi
  return 0
}

#######################################
# Function: check_filesystem
#  - Type: XFS
function check_filesystem(){
  local xfs_repair_flg=0

  for i in $@
  do
    echo "### /sbin/xfs_repair -n $i ###" >>${xfs_repair_log}
    /sbin/xfs_repair -n $i                >>${xfs_repair_log} 2>&1 || (( xfs_repair_flg ++ ))
    echo                                  >>${xfs_repair_log}
  done

  if [ ${xfs_repair_flg} != 0 ]; then
    return 1
  fi
  return 0
}

#######################################
# Check ARG
if [ "$1" != "start" ];then
  echo "ERROR: ARG != start" >&2
  exit 1
fi

#######################################
# Check if DISK exists
file_exists $nfsvol

#######################################
# Stop NFS service
systemctl stop nfs-server.service || abort "systemctl stop nfs-server.service FAILED"

#######################################
# umount NFS Volume for checking Filesystem
mount | grep $nfsvol >/dev/null || abort "$nfsvol does not been mounted before checking filesystem"
umount $nfsvol || abort " umount ${nfsvol} FAILED"

#######################################
# Check Filesystem of target DISK
check_filesystem $dest_dsk $src_dsk

if [ $? != 0 ]; then
  echo "ERROR: xfs check FAILED" >&2
  echo "Saved logfile = ${xfs_repair_log}" >&2
  echo "## LOG ##"
  cat ${xfs_repair_log}
  exit 1
fi

echo "Checking Filesystem has Finished successfully!"

#######################################
# rm logfile
is_vars_defined ${xfs_repair_log}
if [ $? == 0 ]; then
  rm -rf ${xfs_repair_log}
fi

#######################################
# mount NFS Volume
mount -a >/dev/null || abort "mount -a FAILED"
mount | grep $nfsvol >/dev/null || abort "${nfsvol} does not been mounted after checking filesystem"

#######################################
# start NFS service
systemctl start nfs-server.service || abort "systemctl start nfs-server.service FAILED"
systemctl status nfs-server.service | grep "Active: active (exited)" >/dev/null || abort "NFS service is not started"

#######################################
# Make directory fot backup
mkdir -p $dst
chown root:root $dst
chmod 700 $dst

#######################################
# Check if DISK exists
file_exists $dest_dsk $nfsvol

#######################################
# Check if DISK has already been mounted
dsk_sdx=`ls -l $dest_dsk | awk '{ print $11 }' | sed 's/\.\.\/\.\.\///g'`
mflg=0
for i in $dest_dsk $dsk_sdx $dst
do
  mount | grep ${i} >/dev/null 2>&1 && (( mflg ++ ))
  if [ $mflg != 0 ];then
    echo "${i} is already mounted" >&2
    echo "mount failed" >&2
    exit 1
  fi
done

#######################################
# Mount DISK
mount -t xfs $dest_dsk $dst || abort "mount -t xfs $dest_dsk $dst FAILED"
chown root:root $dst
chmod 700 $dst

#######################################
# Exec RSYNC
echo "rsync is started >>>>>>"
echo "# rsync -auvh ${nfsvol}/${parh_subdir} ${dst}/"
rsync -auvh ${nfsvol}/${parh_subdir} ${dst}/
rc=$?
echo "<<<<<< rsync was finished, rc = ${rc}"

#######################################
# Unmount DISK
umount $dst

exit 0