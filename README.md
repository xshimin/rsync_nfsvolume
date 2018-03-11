# rsync_nfsvolume
Example of execution:

    [root@fileserver shells]# ./sync_nfsvolume01.sh start
    Checking Filesystem has Finished successfully!
    rsync is started >>>>>>
    # rsync -auvh /nfsvolume01/share /dest_sync/
    sending incremental file list

    sent 3.36M bytes  received 5.88K bytes  94.83K bytes/sec
    total size is 1357.13G  speedup is 403149.61
    <<<<<< rsync was finished, rc = 0
    [root@fileserver shells]#