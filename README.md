High-level log below contains coarse granularity description of 
milestiones. Fine-grained is in github repo.

In general, experimental setup is composed of 4 layers: (1) hardware, 
(2) system, (3) processes and (4) workload. In the current setup, 1/2 
are fixed and have to be manually configured but in principle it could 
be automated with something like cloud-init or cloudlab. This repo 
contains metadata to make 3/4 fully automated, so for example we can 
launch multiple instances of ceph clusters with distinct 
configurations (e.g. a 3 mon/8 osd cluster with journals on flash on 4 
physical nodes) and execute distinct RADOS benchmarks.

We use [maestro-ng] and its YAML config files to orchestrate 
containers. Ideally, we would like to have ephemeral storage that can 
be mounted/formatted dynamically. Something like what CoreOS' [does], 
however, we will initially do it manually and include the 
configuration as cloud-init syntax in the YAML file. This with the 
purpose of reflecting in code what we're doing manually.

# Dependencies

Tracked via submodules:

  * docker-maestro
  * docker-ceph
  * docker-radosbench
  * docker-gnuplot

Not tracked:

  * [Hardware][hw]
  * Address space: 192.168.141.0/24
  * Ephemeral storage
  * HDDs on sdb-sdd
  * SSD on sde
  * Ubuntu 12.04.3 (docker hosts)
  * Linux 3.8.0-44-generic x86_64
  * docker:
      * Client version: 1.3.1
      * Client API version: 1.15
      * Go version (client): go1.3.3
      * Git commit (client): 4e9bbfa
      * OS/Arch (client): linux/amd64
      * docker hosts listening over TPC on 2375 (default) port
  * NFS folder cephconf shared with all container hosts

# High-level lab log

## 2014-11-27

Obtained figures and results from a small 4-node/8-osd cluster in 
order to compare trends against OSDI paper. Figures 5,6 are similar. 
Figures 7,8 are distinct

## 2014-11-26

  * Took 2 days (11/24-11/26) to finish the scripts that generate 
    graphs from radosbench output.

## 2014-11-25

  * Found CVS folder
  * Created separate docker-radosbench project to maintain the 
    radosbench Dockerfile and evolve it independently from docker-ceph

## 2014-11-24

Carlos provided specific dates of MDS experiments:

> I found the chat of the LLNL ASC experiment. It was on February 
28, 2006. Sage got the ASC cluster from 3:30pm to 5pm the next day 
(3/1/06). Sage worked mostly on MDS experiments.

Also, CVS repository might still exist in NFS.

## 2014-11-22

Finished with high-level orchestration script. We're now in the 
process of reproducing Figs 6-9 of the paper.

## 2014-11-20

Created radosbench Docker image to automate the execution of RADOS. 

## 2014-11-19

YAML config now includes cloud-init syntax that reflects what we're 
doing manually so that we can in the future automate this. So far is 
manual.

Also, configuration now sets up per-HDD OSD. In our cluster, every 
node has 3 hard disk drives. Thus, we can launch 3 OSDs on each node.

## 2014-11-18

Extending configuration so that journals on distinct device than the 
one where OSD data resides can be used.

## 2014-11-17

Created repository in <https://github.com/ivotron/ceph_osdi06>

This can run now a minimal 3-node OSD cluster.

## 2014-11-15

Been working on <https://github.com/Ulexus/docker-ceph> since it's the 
more mature of the above. I've forked it so I can have modifications.

## 2014-11-12

Looking for containerized Ceph. Found

  * <http://www.sebastien-han.fr/blog/2013/09/19/how-I-barely-got-my-first-ceph-mon-running-in-docker/>
  * <http://dachary.org/?p=3250>
  * <https://github.com/Ulexus/docker-ceph>

## 2014-11-11

Selected maestro-ng since it has minimal dependencies.

## 2014-11-10

Started to look on suitable docker-based orchestration utilities. 
Alternatives:

  * Fleet
  * Kubernetes
  * Shipyard
  * Maestro-ng

## 2014-11-07

Carlos will look into his archive to look for chats and emails and try 
to locate the OSDI paper in the repo's timeline.

## 2014-11-06

Started to work on this project. First we looked at the [ceph 
repo][repo] in order to determine what commit ID corresponds to the 
[OSDI '06][paper].

Original repository was in CVS, then Subversion, then Git. Early 
commit messages seem to be lost.

<!--
# References
-->

[does]: https://coreos.com/docs/cluster-management/setup/mounting-storage/
[maestro-ng]: https://github.com/signalfuse/maestro-ng
[emustorage]: https://wiki.emulab.net/wiki/EmulabStorage
[cloud-init]: https://github.com/number5/cloud-init/blob/master/doc/examples/cloud-config-disk-setup.txt
[rackspace]: https://developer.rackspace.com/blog/using-cloud-init-with-rackspace-cloud/
[repo]: https://github.com/ceph/ceph
[paper]: https://www.usenix.org/legacy/event/osdi06/tech/weil.html
[hw]: https://issdm-cluster.soe.ucsc.edu/doku.php?id=hardware
[bug]: http://tracker.ceph.com/issues/7401
