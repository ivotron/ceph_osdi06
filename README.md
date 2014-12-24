# Reproducing Ceph OSDI '06 Paper

This project aims at reproducing some of the experimental results 
included in the 2006 Ceph paper (in particular the scalability 
experiments shown in Figure 8). The goal is to use this exercise as 
use case for reproducibility in Systems Research.

We have the following reproducibility variables (and the values they 
take):

  - _Hardware_. `old | new`
  - _Virtualization_. `os | full | para`
  * _Kernel_. 2.6 vs. 3.13
  * _Code_. paper vs. giant

Code not only denotes the Ceph binaries, but also executable binaries 
and scripts, as well as input files (in other words, the filesystem 
snapshot). The table below shows all the permutations of values that 
every variable can take. We refer to a row as a _setup_.


| Setup | Hardware | Virtualization | Kernel | Code | Time | Outcome |
|:-----:|:--------:|:--------------:|:------:|:----:|:----:|:-------:|
|   01  |   old    |     on         |  new   | new  |      |         |
|   02  |   old    |     on         |  new   | old  |      |         |
|   03  |   old    |     on         |  old   | new  |      |         |
|   04  |   old    |     on         |  old   | old  |      |         |
|   05  |   old    |     off        |  new   | new  |  90  |   RP    |
|   06  |   old    |     off        |  new   | old  |      |         |
|   07  |   old    |     off        |  old   | old  |      |         |
|   08  |   old    |     off        |  old   | new  |      |         |
|   09  |   new    |     on         |  new   | new  |      |         |
|   10  |   new    |     on         |  new   | old  |      |         |
|   11  |   new    |     on         |  old   | old  |      |         |
|   12  |   new    |     on         |  old   | new  |      |         |
|   13  |   new    |     off        |  new   | new  |      |         |
|   14  |   new    |     off        |  new   | old  |      |         |
|   15  |   new    |     off        |  old   | old  |      |         |
|   16  |   new    |     off        |  old   | new  |      |         |

The `Outcome` column corresponds to the outcome of the experiment. 
Possible values are:

  * _RT_. Repeated the experiments with exactly the same numbers.
  * _RP_. Reproduced experiments by validating the original results, 
    in the sense that the same conclusion about the original work can 
    be made. In other words, the experiment is validated
  * NB. Unable to build

The time column corresponds to the time it took to achieve

## Project Files Organization

Every folder in the project corresponds to one of the setups listed 
above. The README on each folder contains the detailed description of 
every setup and its results (sections _Timing_ and _Outcome_ on the 
README).

# Hardware

See [here](https://issdm-cluster.soe.ucsc.edu/doku.php?id=hardware)
