We use [maestro-ng] and its YAML config files to orchestrate 
containers. Ideally, we would like to have ephemeral storage that can 
be mounted/formatted dynamically (see issue #3).

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

# Timing

Total = 3 weeks (15 days x 6hr = 90 hrs)

Since this effort entailed learning tools such as docker and maestro, 
it might be appropriate to cut the time in half (45 hrs, instead of 
90).

## 11/17-28 (2 weeks)

Worked on having a docker-based environment in which to re-generate 
the scalability experiment. Got experiment to run but faced 
variability

## 12/8-12 (1 week)

Worked on stabilizing RADOS (IO throttling)

# Outcome

The experiments on section 6 show the ability of Ceph to saturate disk 
evenly among the drives of the cluster. Figures 5-7 show per-OSD 
performance as the object size varies from 4k to 4m. In our case we 
focus on reproducing the scalability experiment (Figure 8), which uses 
4m objects, to avoid random IO noise from the hard drives.

The original scalability experiment ran with 20 clients per node on 20 
nodes (400 clients total) and varies the number of OSDs from 2-26 in 
increments of 2. Every node was connected via 1 GbE link, so the 
experiment theoretical upper bound is 2GB/s (when there is enough 
capacity of the OSD cluster to have 20 1Gb connections) or 
alternatively when the connection limit of the switch is reached. The 
paper experiments where executed on a Netgear switch which has a 
capacity of approximately 14 GbE in _real_ total traffic (from a 20 
advertised), which corresponds to the 24 * 58 = 1400 MB/s combined 
throughput.

We scaled down the experiment by reducing the number of clients to 1 
node (16 clients). This means that our network upper bound is 110 MB/s 
(the capacity of the 1GbE link from the client to the switch). We 
throttle IO at 30 MB/s (vs. 58 MB/s of the original paper), so our 
scaling unit is 30 per OSD. Given this scaling, we obtain the results 
shown in figure 1.

![Reproducing figure 8 of the original OSDI '06 paper on a scaled down 
version of the original hardware](results/throttle_30mb_per-osd-scalable-throughput.csv.png)

We see that the Ceph scales linearly with the number of OSDs, up to 
the point where we saturate the 1GbE link.

<!--
# References
-->

[maestro-ng]: https://github.com/signalfuse/maestro-ng
[hw]: https://issdm-cluster.soe.ucsc.edu/doku.php?id=hardware
