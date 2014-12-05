#!/bin/bash
#
# executes the entire experiment. This generates the data and/or figures 5-8 of
# OSDI paper.
#

YEAR=`date +%Y`
MONTH=`date +%m`
DAY=`date +%d`
TIME=`date +%H%M`
EXP="${YEAR}_${MONTH}_${DAY}_${TIME}"

usage()
{
  echo ""
  echo "Usage: $0: [OPTIONS]"
  echo " -e : Execute experiment ([y|n] default: y)."
  echo " -f : Generate figures ([y|n] default: y)."
  echo " -d : Execute using default values ([y|n] default: n)."
  echo " -c : ceph configuration path (Default: '$PWD/cephconf/')."
  echo " -o : path to folder containing experimental results (Default: '$PWD/results/')."
  echo " -s : Set the runtime in seconds (default: 60)."
  echo " -m : Maximum number of OSDs (default: 3)."
  echo " -n : Experiment name (default: time-based [e.g. $EXP])."
  echo " -h : Show this help & exit"
  echo ""
  exit 1
}

ceph_health()
{
  echo -n "Waiting for pool operation to finish..."
  while [ "$($c health)" != "HEALTH_OK" ] ; do
    sleep 2
    echo -n "."
  done
  echo ""
}

while getopts ":c:d:e:f:m:n:o:s:h" OPTION
do
  case ${OPTION} in
  c)
    CEPHCONF="${OPTARG}"
    ;;
  d)
    USE_DEFAULTS="${OPTARG}"
    ;;
  e)
    RUN_EXP="${OPTARG}"
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
  r)
    R="${OPTARG}"
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

if [ ! -n "$RUN_EXP" ] ; then
  THROUGHPUT_EXP="y"
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
  SECS=15
fi
if [ ! -n "${MAX_NUM_OSD}" ]; then
  MAX_NUM_OSD=3
elif [ "$MAX_NUM_OSD" -lt 3 ] ; then
  echo "ERROR: MAX_NUM_OSD has to be at least 3"
  exit 1
fi
if [ ! -n "$PER_ROUND_OSD_INCREMENT" ]; then
  PER_ROUND_OSD_INCREMENT=1
fi

###################
# docker/maestro basics
###################

m="docker run -v `pwd`:/data ivotron/maestro:0.2.3"
c="docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph"

# check if we can execute docker
docker_exists=`type -P docker &>/dev/null && echo "found" || echo "not found"`

if [ $docker_exists = "not found" ]; then
  echo "ERROR: can't execute docker, make sure it's reachable via PATH"
  exit 1
fi

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

# Run experiment
#
# Executes write benchmarks from n=1 to MAX_NUM_OSD with replication factor
# 1 and 4m objects. This corresponds to figure 8.
#
# When n=MAX_NUM_OSD object size ranges from 4k to 4m, which corresponds to the
# red line in figures 5,6. Read (seq) benchmarks are also executed, which are
# used for figure 7.

if [ $RUN_EXP = "y" ] ; then

num_osds=1

while [ "$num_osds" -le "$MAX_NUM_OSD" ] ; do

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

$c osd pool delete rbd rbd --yes-i-really-really-mean-it

if [ $? != "0" ] ; then
  echo "ERROR: while deleting rbd pool"
  exit 1
fi

# start osds
for ((osd_id=1; osd_id<=num_osds; osd_id++)) ; do
  $c osd create

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

# create pool
$c osd pool create test
ceph_health

$c osd pool set test size 1

if [ $num_osds -eq $MAX_NUM_OSD ] ; then
  SIZE="4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304"
else
  SIZE="4194304"
fi


for size in $SIZE; do

  f="$RESULTS_PATH/$EXP/$num_osds/$size/write/"
  mkdir -p $f

  cat maestro.yaml > maestro_with_vars.yaml
  echo "_globals:" >> maestro_with_vars.yaml
  echo "  V1: &objsize $size" >> maestro_with_vars.yaml
  echo "  V2: &testname $EXP" >> maestro_with_vars.yaml
  echo "  V3: &resultsfolder $f" >> maestro_with_vars.yaml
  echo "  V4: &sec $SECS" >> maestro_with_vars.yaml
  echo "  V5: &benchtype write" >> maestro_with_vars.yaml

  $m -f /data/maestro_with_vars.yaml start ceph-radosbench

  if [ $? != "0" ] ; then
    echo "ERROR: can't initialize radosbench services"
    exit 1
  fi

  bench_up=`$m status ceph-radosbench | grep 'running for' | wc -l`

  if [ $bench_up -eq 0 ] ; then
    echo "ERROR: bench service seems to have stopped"
    exit 1
  fi

  if [ "$num_osds" -eq $MAX_NUM_OSD ] ; then
    f="$RESULTS_PATH/$EXP/$num_osds/$size/seq/"
    mkdir -p $f

    cat maestro.yaml > maestro_with_vars.yaml
    echo "_globals:" >> maestro_with_vars.yaml
    echo "  V1: &objsize $size" >> maestro_with_vars.yaml
    echo "  V2: &testname $EXP" >> maestro_with_vars.yaml
    echo "  V3: &resultsfolder $f" >> maestro_with_vars.yaml
    echo "  V4: &sec $SECS" >> maestro_with_vars.yaml
    echo "  V5: &benchtype seq" >> maestro_with_vars.yaml

    $m -f /data/maestro_with_vars.yaml start ceph-radosbench

    if [ $? != "0" ] ; then
      echo "ERROR: can't initialize radosbench services"
      exit 1
    fi

    bench_up=`$m status ceph-radosbench | grep 'running for' | wc -l`

    if [ $bench_up -eq 0 ] ; then
      echo "ERROR: bench service seems to have stopped"
      exit 1
    fi

    fi
done
done

# stop cluster
$m stop

# execute cleanup containers
$m start ceph-osd-cleanup

if [ $? != "0" ] ; then
  echo "ERROR: unexpected error while cleaning"
  exit 1
fi

sleep 10

fi

if [ -n "$GENERATE_FIGURES" ] ; then
  # generates CSV files that summarize radosbench output (one CSV per figure)
  #
  # expects to have results stored in the following folder structure:
  #   results/experiment_name/osd_count/objsize_type.csv

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

  # populate them
  for osd in `ls $expath` ; do
  for size in `ls $expath/$osd` ; do
  for bench in `ls $expath/$osd/$size/*` ; do
  for client in `ls $expath/$osd/$size/$bench/*` ; do
    f="$expath/$osd/$size/$bench/$client"

    if [ $bench = "write" ] ; then
      tp=`grep 'Bandwidth (MB/sec):' $f | sed 's/Bandwidth (MB\/sec): *//'`
      lt=`grep 'Average Latency:' $f | sed 's/Average Latency: *//'`
      echo "$size, $client, $tp" >> $throughput
      echo "$size, $client, $lt" >> $latency
      echo "$osd, $size, $client, $tp" >> $scale
    elif
      r=`grep 'Bandwidth (MB/sec):' $f | sed 's/Bandwidth (MB\/sec): *//'`
      echo "$size, $client, $r" >> $rw
    fi
  done
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
