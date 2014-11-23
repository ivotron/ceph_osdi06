#!/bin/bash
#
# executes the entire experiment. This generates the data for figures 6-9 of 
# OSDI paper.
#
# assumes disks are partitioned and mounted as specified in maestro.yaml

usage()
{
  echo ""
  echo "Usage: $0: [OPTIONS]"
  echo " -c : ceph configuration path (required)."
  echo " -o : path to folder containing experimental results (required)."
  echo " -r : Set the maximum pool replica count (default: 1)."
  echo " -p : Number of placement groups for the rados bench pool (default: 4k)."
  echo " -s : Set the runtime in seconds (default: 60)."
  echo " -m : Maximum number of OSDs (default: 1)."
  echo " -n : Minimum number of OSDs (default: 1)."
  echo " -i : Increment in number of OSDs per experiment round (default: 2)."
  echo " -t : Number of clients that execute radosbench (default: 1)."
  echo " -z : Number of monitor nodes (default: 1)."
  echo " -b : Number of repetitions of an experiment (default: 10)."
  echo " -h : Show this help & exit"
  echo ""
  exit 1
}

while getopts 'c:o:r:p:s:m:n:i:t:z:b:h' OPTION
do
  case ${OPTION} in
  c)
    CEPHCONF="${OPTARG}"
    ;;
  o)
    RESULTS_PATH="${OPTARG}"
    ;;
  r)
    MAX_REPLICAS="${OPTARG}"
    ;;
  p)
    PGS="${OPTARG}"
    ;;
  s)
    SECS="${OPTARG}"
    ;;
  m)
    MAX_NUM_OSD="${OPTARG}"
    ;;
  n)
    MIN_NUM_OSD="${OPTARG}"
    ;;
  i)
    PER_ROUND_OSD_INCREMENT="${OPTARG}"
    ;;
  t)
    NUM_CLIENTS="${OPTARG}"
    ;;
  z)
    NUM_MON="${OPTARG}"
    ;;
  b)
    REPS="${OPTARG}"
    ;;
  h)
    usage
    ;;
  esac
done

if [ ! -n "$CEPHCONF" ]; then
  echo "Path to ceph configuration folder required"
  exit 1
fi

if [ ! -n "$RESULTS_PATH" ]; then
  echo "Path to results folder required"
  exit 1
fi

if [ ! -n "$MAX_REPLICAS" ]; then
  MAX_REPLICAS=1
fi

if [ ! -n "$PGS" ]; then
  PGS=4096
fi

if [ ! -n "$SECS" ]; then
  SECS=10
fi

if [ ! -n "${MAX_NUM_OSD}" ]; then
  MAX_NUM_OSD=1
fi

if [ ! -n "${MIN_NUM_OSD}" ]; then
  MIN_NUM_OSD=1
fi

if [ ! -n "$PER_ROUND_OSD_INCREMENT" ]; then
  PER_ROUND_OSD_INCREMENT=2
fi

if [ ! -n "$NUM_CLIENTS" ]; then
  NUM_CLIENTS=1
fi

if [ ! -n "$NUM_MON" ]; then
  NUM_MON=1
fi

if [ ! -n "$REPS" ]; then
  REPS=10
fi

# check if we can execute docker
docker_exists=`type -P docker &>/dev/null && echo "found" || echo "not found"`

if [ $docker_exists = "not found" ]; then
  echo "ERROR: can't execute docker, make sure it's reachable via PATH"
  exit 1
fi

m="docker run -t -v `pwd`:/data ivotron/maestro"

# check num of MON services
num_mon_services=`$m status ceph-mon | grep ceph-mon | wc -l`

if [ $? != "0" ] ; then
  echo "ERROR: can't execute maestro container"
  exit 1
fi

if [ $num_mon_services != "$NUM_MON" ] ; then
  echo "ERROR: Can't execute, need to have exactly $NUM_MON services"
  exit 1
fi

# check num of OSD services
num_osd_services=`$m status ceph-osd | grep ceph-osd | wc -l`

if [ "$num_osd_services" -lt "$MAX_NUM_OSD" ] ; then
  echo "ERROR: Can't execute, need at least $MAX_NUM_OSD services"
  exit 1
fi

# check if docker hosts are up
hosts_down=`$m status | grep 'host down' | wc -l`

if [ $hosts_down != "0" ] ; then
  echo "ERROR: One or more docker hosts are down"
  exit 1
fi

num_osds=$MIN_NUM_OSD

while [ "$num_osds" -le "$MAX_NUM_OSD" ] ; do

  # start monitor
  $m start ceph-mon

  if [ $? != "0" ] ; then
    echo "ERROR: can't initialize monitor service"
    exit 1
  fi

  mons_up=`$m status ceph-mon | grep 'running for' | wc -l`

  if [ $mons_up != $NUM_MON ] ; then
    echo "ERROR: Expecting $NUM_MON up, but only $mons_up are up"
    exit 1
  fi

  docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base /usr/bin/ceph osd pool delete rbd rbd --yes-i-really-really-mean-it

  if [ $? != "0" ] ; then
    echo "ERROR: while deleting rbd pool"
    exit 1
  fi

  # start osds
  for ((osd_id=1; osd_id<=num_osds; osd_id++)) ; do
    docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base /usr/bin/ceph osd create

    if [ $? != "0" ] ; then
      echo "ERROR: can't create OSD $osd_id"
      exit 1
    fi

    $m start ceph-osd-$osd_id

    if [ $? != "0" ] ; then
      echo "ERROR: can't initialize osd service $osd_id"
      exit 1
    fi

    osd_up=`$m status ceph-osd-$osd_id | grep 'running for' | wc -l`

    if [ $osd_up != "1" ] ; then
      echo "ERROR: OSD service ceph-osd-$osd_id seems to have stopped"
      exit 1
    fi
  done

  # execute benchmark
  docker run \
      -e SIZE="4096 4194304" \
      -e SEC=$SECS -e N=$MAX_REPLICAS -e PGS=$PGS -e REPS=$REPS \
      -v $RESULTS_PATH:/data \
      -v $CEPHCONF:/etc/ceph \
      ivotron/radosbench

  # stop cluster
  $m stop

  # execute cleanup containers
  $m start ceph-osd-cleanup

  if [ $? != "0" ] ; then
    echo "ERROR: unexpected error while cleaning"
    exit 1
  fi

  num_osds=$(($num_osds + $PER_ROUND_OSD_INCREMENT))

done

exit 0
