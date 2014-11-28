#!/bin/bash
#
# executes the entire experiment. This generates the data and/or figures 5-8 of 
# OSDI paper.
#

usage()
{
  echo ""
  echo "Usage: $0: [OPTIONS]"
  echo " -a : Execute throughput experiment ([y|n] default: y)."
  echo " -b : Execute scalability experiment ([y|n] default: y)."
  echo " -f : Generate figures ([y|n] default: y)."
  echo " -d : Execute using default values ([y|n] default: n)."
  echo " -c : ceph configuration path (Default: '$PWD/cephconf/')."
  echo " -o : path to folder containing experimental results (Default: '$PWD/results/')."
  echo " -s : Set the runtime in seconds (default: 60)."
  echo " -m : Maximum number of OSDs (default: 3)."
  echo " -n : Experiment name (default: time-based name)."
  echo " -h : Show this help & exit"
  echo ""
  exit 1
}

while getopts ":a:b:c:d:f:m:n:o:s:h" OPTION
do
  case ${OPTION} in
  a)
    THROUGHPUT_EXP="${OPTARG}"
    ;;
  b)
    SCALABILITY_EXP="${OPTARG}"
    ;;
  c)
    CEPHCONF="${OPTARG}"
    ;;
  d)
    USE_DEFAULTS="${OPTARG}"
    ;;
  f)
    GENERATE_FIGURES="${OPTARG}"
    ;;
  m)
    MAX_NUM_OSD="${OPTARG}"
    ;;
  n)
    EXP="${OPTARG}"
    ;;
  o)
    RESULTS_PATH="${OPTARG}"
    ;;
  s)
    SECS="${OPTARG}"
    ;;
  h)
    usage
    ;;
  esac
done

# we really don't need the -d flag, since the experiment can execute directly,
# but we want to have people read the usage notes so that they know what the
# defaults are doing
if [ $OPTIND -eq 1 ]; then
  usage
fi

###################
# Validate arguments
###################

if [ ! -n "$THROUGHPUT_EXP" ] ; then
  THROUGHPUT_EXP="y"
fi
if [ ! -n "$SCALABILITY_EXP" ] ; then
  SCALABILITY_EXP="y"
fi
if [ ! -n "$GENERATE_FIGURES" ]; then
  GENERATE_FIGURES="y"
fi
if [ ! -n "$CEPHCONF" ]; then
  CEPHCONF=$PWD/cephconf
fi
if [ ! -n "$RESULTS_PATH" ]; then
  RESULTS_PATH=$PWD/results
fi
if [ ! -n "$SECS" ]; then
  SECS=60
fi
if [ ! -n "${MAX_NUM_OSD}" ]; then
  MAX_NUM_OSD=3
elif [ "$MAX_NUM_OSD" -lt 3 ] ; then
  echo "ERROR: MAX_NUM_OSD has to be at least 3"
  exit 1
fi
if [ ! -n "$PER_ROUND_OSD_INCREMENT" ]; then
  PER_ROUND_OSD_INCREMENT=2
fi
if [ ! -n "$EXP" ] ; then
  YEAR=`date +%Y`
  MONTH=`date +%m`
  DAY=`date +%d`
  TIME=`date +%H%M`
  EXP="${YEAR}_${MONTH}_${DAY}_${TIME}"
fi

###################
# docker/maestro basics
###################

# check if we can execute docker
docker_exists=`type -P docker &>/dev/null && echo "found" || echo "not found"`

if [ $docker_exists = "not found" ]; then
  echo "ERROR: can't execute docker, make sure it's reachable via PATH"
  exit 1
fi

m="docker run -v `pwd`:/data ivotron/maestro:0.2.3"

# check if maestro runs OK
$m status

if [ $? != "0" ] ; then
  echo "ERROR: can't execute maestro container"
  exit 1
fi

# check num of MON services
num_mon_services=`$m status ceph-mon | grep down | wc -l`

if [ $? != "0" ] ; then
  echo "ERROR: can't execute maestro container"
  exit 1
fi

if [ "$num_mon_services" -ne 1 ] ; then
  echo "ERROR: Can't execute, need to have exactly 1 service"
  exit 1
fi

# check num of OSD services
num_osd_services=`$m status ceph-osd | grep down | wc -l`

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

###########################
# Throughput experiments
###########################

if [ $THROUGHPUT_EXP = "y" ] ; then

num_osds=3

# start monitor
$m start ceph-mon

if [ $? != "0" ] ; then
  echo "ERROR: can't initialize monitor service"
  exit 1
fi

mons_up=`$m status ceph-mon | grep 'running for' | wc -l`

if [ "$mons_up" -ne 1 ] ; then
  echo "ERROR: Expecting 1 monitor up, but only $mons_up are up"
  exit 1
fi

docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph osd pool delete rbd rbd --yes-i-really-really-mean-it

if [ $? != "0" ] ; then
  echo "ERROR: while deleting rbd pool"
  exit 1
fi

# start osds
for ((osd_id=1; osd_id<=num_osds; osd_id++)) ; do
  docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph osd create

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
#
# This executes write benchmarks for N=1,2,3 which corresponds to figures 5,6.
#
# For N=1, read (seq) benchmarks are also executed, corresponding to figure 7.

for ((n=1; n<=N; n++)); do
  if [ "$n" -eq 1 ] ; then
    docker run \
      -e RESULTS_PATH="/data/$EXP" \
      -e SEQ="yes" \
      -e NUM_OSD=$num_osds \
      -e SEC=$SECS \
      -e N=$n \
      -v $RESULTS_PATH:/data \
      -v $CEPHCONF:/etc/ceph \
      ivotron/radosbench:0.2
  else
    docker run \
      -e RESULTS_PATH="/data/$EXP" \
      -e NUM_OSD=$num_osds \
      -e SEC=$SECS \
      -e N=$n \
      -v $RESULTS_PATH:/data \
      -v $CEPHCONF:/etc/ceph \
      ivotron/radosbench:0.2
  fi
done

# stop cluster
$m stop

# execute cleanup containers
$m start ceph-osd-cleanup

if [ $? != "0" ] ; then
  echo "ERROR: unexpected error while cleaning"
  exit 1
fi

sleep 300

fi

##########################
# Scalability experiments
##########################

if [ $SCALABILITY_EXP = "y" ] ; then

num_osds=2

while [ "$num_osds" -le "$MAX_NUM_OSD" ] ; do

  # start monitor
  $m start ceph-mon

  if [ $? != "0" ] ; then
    echo "ERROR: can't initialize monitor service"
    exit 1
  fi

  mons_up=`$m status ceph-mon | grep 'running for' | wc -l`

  if [ $mons_up != 1 ] ; then
    echo "ERROR: Expecting 1 up, but $mons_up are up"
    exit 1
  fi

  docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph osd pool delete rbd rbd --yes-i-really-really-mean-it

  if [ $? != "0" ] ; then
    echo "ERROR: while deleting rbd pool"
    exit 1
  fi

  # start osds
  for ((osd_id=1; osd_id<=num_osds; osd_id++)) ; do
    docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph osd create

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

  # execute benchmark. Results correspond to Figure 8.
  docker run \
      -e NUM_OSD=$num_osds \
      -e SEC=$SECS \
      -e N=1 \
      -e RESULTS_PATH="/data/$EXP" \
      -e SIZE="4194304" \
      -v $RESULTS_PATH:/data \
      -v $CEPHCONF:/etc/ceph \
      ivotron/radosbench:0.2

  # stop cluster
  $m stop

  # execute cleanup containers
  $m start ceph-osd-cleanup

  if [ $? != "0" ] ; then
    echo "ERROR: unexpected error while cleaning"
    exit 1
  fi

  sleep 300

  num_osds=$(($num_osds + $PER_ROUND_OSD_INCREMENT))

done

fi

if [ -n "$GENERATE_FIGURES" ] ; then
  # generates CSV files that summarize radosbench output (one CSV per figure)
  #
  # expects to have results stored in the following folder structure:
  #   results/experiment_name/osd_count/num_replica/obj_size/type.csv

  if [ ! -n "$RESULTS_PATH" ]; then
    echo "ERROR: RESULTS_PATH must be defined"
    exit 1
  fi

  if [ ! -n "$EXP" ]; then
    echo "ERROR: EXPERIMENT must be defined"
    exit 1
  fi

  throughput=${RESULTS_PATH}/${EXP}_per-osd-write-throughput.csv
  latency=${RESULTS_PATH}/${EXP}_per-osd-write-latency.csv
  rw=${RESULTS_PATH}/${EXP}_per-osd-rw-throughput.csv
  scale=${RESULTS_PATH}/${EXP}_per-osd-scalable-throughput.csv
  expath=$RESULTS_PATH/$EXP

  # create files
  touch $throughput # figure 5
  touch $latency    # figure 6
  touch $rw         # figure 7
  touch $scale      # figure 8

  # throughput CSVs
  for replicas in `ls $expath/3/` ; do
    for size in `ls $expath/3/$replicas/` ; do
      tp=`grep 'Bandwidth (MB/sec):' $expath/3/$replicas/$size/write.csv | sed 's/Bandwidth (MB\/sec): *//'`
      lt=`grep 'Average Latency:' $expath/3/$replicas/$size/write.csv | sed 's/Average Latency: *//'`
      echo "$replicas, $size, $tp" >> $throughput
      echo "$replicas, $size, $lt" >> $latency

      if [ $replicas = "1" ] ; then
        r=`grep 'Bandwidth (MB/sec):' $expath/3/$replicas/$size/seq.csv | sed 's/Bandwidth (MB\/sec): *//'`
        echo "$size, $r, $tp" >> $rw
      fi
    done
  done

  # scalability CSVs
  for osd in `ls $expath` ; do
    for replicas in `ls $expath/$osd/` ; do
      for size in `ls $expath/$osd/$replicas/` ; do
        tp=`grep 'Bandwidth (MB/sec):' $expath/$osd/$replicas/$size/write.csv | sed 's/Bandwidth (MB\/sec): *//'`
        echo "$osd, $size, $tp" >> $scale
      done
    done
  done

  # generate the figures (png files)
  docker run \
      -v $RESULTS_PATH:/results \
      -v $PWD:/script \
      ivotron/gnuplot:4.6.4 -e "maxosd=$MAX_NUM_OSD" \
                      -e "folder='/results'" \
                      -e "experiment=\'$EXP\'" \
                      /script/plot.gp
fi

exit 0
