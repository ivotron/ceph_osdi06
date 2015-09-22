# Reproducing Ceph OSDI '06

This project aims at reproducing some of the experimental results 
included in the 2006 Ceph paper (in particular the scalability 
experiments shown in Figure 8). The goal is to use this exercise to 
study some of the issues in reproducibility of Systems Research.

## Reproducing the scalability experiment

For a high-level description, please read Section 4 of [this 
document][this]. To re execute the experiments:

 1. checkout submodules (`git submodule update --init --recursive`).
 2. install docker in one or more hosts (see [here] for quickly 
    installing docker on multiple nodes using ansible).
 3. edit `nodes` and specify the list of nodes where docker was 
    installed in 2.
 4. launch experiment:

    ``` bash
    ./run \
        -k ~/.ssh/id_rsa.pub \
        -o `pwd`/results/ \
        -u remoteuser -b
    ```

    Where `remoteuser` is a user that has sudo privileges on remote 
    hosts. The default behavior is to assume a partition on 
    `/dev/sdb1` is available and mounted at `/mnt/vol1`. The 
    experiment creates a cgroup and assigns the instantiated ceph 
    containers to it. For a complete list of options execute `run 
    --help`.

## Dependencies

On local host:

  * ansible 1.9+
  * docker 1.7+

On remote nodes, docker 1.7+ is required (with daemon listening on the 
default 2375 tcp port). Also, a dedicated `/dev/sdb` storage device is 
expected, which can be optionally partitioned and formated as part of 
the experiment setup. The setup can also install docker on remote 
nodes that run Ubuntu 14.04+ ().

[here]: https://github.com/marklee77/ansible-role-docker
[qa]: https://github.com/ceph/ceph-qa-suite@wip-12379
[teuth]: https://github.com/ceph/teuthology@wip-11892
[this]: https://www.soe.ucsc.edu/research/technical-reports/UCSC-SOE-15-07/download
