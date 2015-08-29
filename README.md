# Steps

 0. checkout submodules (`git submodule update --init --recursive`)
 1. boot swarm cluster; see <https://github.com/systemslab/infra>
 2. run ansible playbook
 3. invoke run.py

All the above in `experiment.sh`.

# Assumptions

  * docker daemon listening to 2375 (wherever this repo is cloned)
  - an ansible-managed cluster (reachable from machine where repo is 
    cloned)
  * suites branch: ceph/ceph-qa-suite@wip-12379
  * teuthology branch: ceph/teuthology@wip-11892

# Dependencies

  * git
  * docker 1.7+
  * swarm 0.4+
  * ansible 1.9+

