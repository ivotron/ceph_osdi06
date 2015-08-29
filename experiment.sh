# TODO:
#   - swarm setup
#   - disk preparation
#   - options to select what to run

remotes_list="issdm-12,issdm-18,issdm-20,issdm-37,issdm-38,issdm-42,issdm-45,"
remotes_list+="192.168.140.81,192.168.140.82,192.168.140.83,192.168.140.84"

python launch_remotes.py \
    -l $remotes_list \
    -k '/home/ivo/.ssh/authorized_keys' \
    -o `pwd`/results
