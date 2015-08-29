#!/usr/bin/python

import argparse
from subprocess import check_call

parser = argparse.ArgumentParser(description='Run scalability test')
parser.add_argument(
    '-r', '--remotes', help='List of remotes where to choose from',
    nargs='+', required=True)
parser.add_argument(
    '-k', '--sshkey', help='file with ssh key', required=True)
parser.add_argument(
    '-o', '--output', help='Output folder with results', required=True)
args = vars(parser.parse_args())

remotes = args['remotes']
keyfile = args['sshkey']
for remote_id in range(0, len(remotes)):
    check_call(
        ("docker run "
         "-d --name=teuthology_remote_{r} "
         "-p 2222:22 "
         "-e AUTHORIZED_KEYS=\"`cat {k}`\" "
         "-v /dev:/dev "
         "-v /tmp/varlibceph/`cat /dev/urandom | tr -cd 'a-f0-9' | "
         "     head -c 32`:/var/lib/ceph "
         "--cap-add=SYS_ADMIN --privileged --device /dev/fuse "
         "--cgroup-parent=ceph "
         "-e 'affinity:node=={n}' "
         "ivotron/ceph-base").format(r=remote_id, keyfile, n=remotes[remote_id]),
        shell=True)

with open('teuthology_task.yml', 'a') as yml:
    yml.write("targets:")
    for remote_id in range(0, len(remotes)):
        yml.write('  root@' + remotes[remote_id] + ' ssh-dss ignored')

check_call(
    ("docker run "
     "-v vendor/ceph-qa-suite:/tmp/suite "
     "-v test.yml:/tmp/test.yml "
     "-v {}/`date +%s`:/archive "
     "ivotron/teuthology:docker "
     "    --archive /archive "
     "    --suite-path /tmp/suite "
     "    /tmp/test.yml ").format(args['output']),
    shell=True)

for remote_id in range(0, len(remotes)):
    check_call("docker kill teuthology_remote_{}".format(remote_id))
    check_call("docker rm teuthology_remote_{}".format(remote_id))
