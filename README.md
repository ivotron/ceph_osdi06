# General steps

Start the monitor:

    docker run ivotron/maestro maestro ceph-mon

Check status:

    docker run -v /path/to/ceph/conf:/etc/ceph ivotron/ceph-base /usr/bin/ceph status

Create IDs for every OSD that will be part of the cluster:

    docker run -v /path/to/ceph/conf:/etc/ceph ivotron/ceph-base /usr/bin/ceph osd create

The example contains 3 OSDs, so the above is done 3 times, generating \[0-2\]. Next, start the osd daemons

    docker run ivotron/maestro maestro ceph-osd

Check status again:

    docker run -v /path/to/ceph/conf:/etc/ceph ivotron/ceph-base /usr/bin/ceph status

Run rados bench

    docker run -v /path/to/ceph/conf:/etc/ceph ivotron/ceph-base /usr/bin/rados -p test bench 10 write

# Dependencies

Tracked via submodules:

  * docker-maestro
  * docker-ceph
  * docker-notebook

Not tracked:

  * IP subnet 192.168.140.0/24
  * unmounted storage drives
  * HDD on sdb-sdd
  * SSD on sde
  * Ubuntu 12.04.3 (docker host)
  * Linux 3.8.0-44-generic x86_64
  * docker:
      * Client version: 1.3.1
      * Client API version: 1.15
      * Go version (client): go1.3.3
      * Git commit (client): 4e9bbfa
      * OS/Arch (client): linux/amd64
      * docker hosts listening over TPC on 2375 (default) port
  * nfs folder cephconf shared with all container hosts
