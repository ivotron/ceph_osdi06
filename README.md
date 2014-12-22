

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

  * docker-maestro-ng
  * docker-ceph
  * docker-radosbench
  * docker-r

Not tracked:

  * [Hardware][hw]
  * Address space: 192.168.141.0/24
  * Ephemeral storage
  * HDDs on sdb-sdd
  * Ubuntu 12.04.3 (docker hosts)
  * Linux 3.13.0-43-generic x86_64
  * docker:

        Client version: 1.3.3
        Client API version: 1.15
        Go version (client): go1.3.3
        Git commit (client): d344625
        OS/Arch (client): linux/amd64
        Server version: 1.3.3
        Server API version: 1.15
        Go version (server): go1.3.3
        Git commit (server): d344625

  * NFS folders `$PWD/cephconf` and `$PWD/results` shared with all 
    container hosts

# High-level lab log

## 2014-12-12

Removed read test and left only the scalability experiments (4mb that 
range from 1-n, where n is the maximum number of OSD nodes to test 
against), to simplify. The experiments on section 6.1 of the paper 
show the ability of Ceph to balance the load of the cluster by 
illustrating how disks are pushed to their limits, up to the point 
where the network becomes the bottleneck.

We initially experienced a lot of variance in our results due to the 
fact that disks in our testbed vary in their performance from 30-90 
mb/s. CRUSH has the ability to weight distinct devices but we're not 
tuning the CRUSH map (every device has the same weight). As an 
alternative, we're throttling IO in order to have a uniform, 
controlled setting.

We reduce the experiment from 20 client nodes to 1. This client is 
connected to the switch on a 1 Gb link. Thus the experiment is limited 
to execute at ~ 110 MB/s.

Since disks are throttled to 30MB/s and we collocate the write-ahead 
log and data on the same device, the throughput is approximately 10-15 
MB/s per node.

## 2014-12-03

Noticed many OSD failures are experienced throughout the experiment. 
Ceph considers an OSD as failed when it timouts on an operation. This 
hardware is almost 10 years old, so it might be the result of old 
disks.

While Ceph is able to heal itself, the results get screwed up if some 
OSDs go down while an experiment runs. So I have to keep a thread that 
periodically checks the health of the cluster and record that. If 
during an experiment there are failures, then I re-execute until I get 
failure-free results. Something I noticed is that, when I don't 
throttle I/O (see entry above) the failure-rate increases. I think 
this might be due to the fact that the hard disks are pushed to their 
limits and this might trigger failures (Ceph considers an OSD down 
when it times out on a I/O request, with 30 seconds being the 
default).

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
process of reproducing Figs 5-8 of the paper.

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
