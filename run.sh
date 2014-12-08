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
  echo " -b : Space-separated list of object size in bytes ([y|n] default: 4MB)."
  echo " -o : path to folder containing experimental results (Default: '$PWD/results/')."
  echo " -s : Set the runtime in seconds (default: 15)."
  echo " -m : Maximum number of OSDs (default: 2)."
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

wait_for_radosbench ()
{
  echo -n "Waiting for radosbench operation to finish..."

  while [ "$($m status ceph-radosbench | grep 'running for' | wc -l)" -ne 0 ] ; do
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
  b)
    SIZE="${OPTARG}"
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
  MAX_NUM_OSD=2
fi
if [ ! -n "${SIZE}" ]; then
  MAX_NUM_OSD=4194304
fi
if [ ! -n "$PER_ROUND_OSD_INCREMENT" ]; then
  PER_ROUND_OSD_INCREMENT=1
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

# check if maestro runs OK
m="docker run -v `pwd`:/data ivotron/maestro:0.2.3"

$m status

if [ $? != "0" ] ; then
  echo "ERROR: can't execute maestro container"
  exit 1
fi

###############
# Run experiment
###############

# Executes write benchmarks from n=1 to MAX_NUM_OSD with replication factor
# 1 and 4m objects. This corresponds to figure 8.
#
# When n=MAX_NUM_OSD, object size ranges from 4k to 4m, which corresponds to the
# red line in figures 5,6. Read (seq) benchmarks are also executed, which are
# used for figure 7.

if [ $RUN_EXP = "y" ] ; then

c="docker run -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph"

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

curr_osd=1

while [ "$curr_osd" -le "$MAX_NUM_OSD" ] ; do

  $c osd pool delete test test --yes-i-really-really-mean-it

  # add osd
  $c osd create

  if [ $? != "0" ] ; then
    echo "ERROR: can't create OSD $curr_osd"
    exit 1
  fi

  $m start ceph-osd-$curr_osd

  if [ $? != "0" ] ; then
    echo "ERROR: can't initialize osd service $curr_osd"
    exit 1
  fi

  osd_up=`$m status ceph-osd-$curr_osd | grep 'running for' | wc -l`

  if [ $osd_up != "1" ] ; then
    echo "ERROR: OSD service ceph-osd-$curr_osd seems to have stopped"
    exit 1
  fi

  # create pool (set PGs to 128 * OSD)
  if [ "$curr_osd" -eq 1 ] ; then
    $c osd pool create test 128 128
  elif [ "$curr_osd" -eq 2 ] ; then
    $c osd pool create test 256 256
  elif [ "$curr_osd" -eq 3 ] ; then
    $c osd pool create test 384 384
  elif [ "$curr_osd" -eq 4 ] ; then
    $c osd pool create test 512 512
  elif [ "$curr_osd" -eq 5 ] ; then
    $c osd pool create test 640 640
  elif [ "$curr_osd" -eq 6 ] ; then
    $c osd pool create test 768 768
  else
    $c osd pool create test 4096 4096
  fi

  # set replication factor to 1
  $c osd pool set test size 1

  # wait for it
  ceph_health

  # when we reach the max num of OSDs, we execute on distinct sizes
  if [ $curr_osd -eq $MAX_NUM_OSD ] ; then
    SIZE="4096 8192 16384 32768 65536 131072 262144 524288 1048576 2097152 4194304"
  fi

  for size in $SIZE; do

    f="$RESULTS_PATH/$EXP/$curr_osd/$size/write/"
    mkdir -p $f

    $m start ceph-radosbench

    if [ $? != "0" ] ; then
      echo "ERROR: can't initialize radosbench services"
      exit 1
    fi

    wait_for_radosbench
  done

  curr_osd=$(($curr_osd + $PER_ROUND_OSD_INCREMENT))

done # while

# stop cluster
$m stop

# execute cleanup containers
$m start ceph-osd-cleanup

if [ $? != "0" ] ; then
  echo "ERROR: unexpected error while cleaning"
  exit 1
fi

fi # RUN_EXP

if [ "$GENERATE_FIGURES" = "y" ] ; then
  # generates CSV files that summarize radosbench output (one CSV per figure)

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
  echo "" > $throughput # figure 5
  echo "" > $latency    # figure 6
  echo "" > $scale      # figure 8

  # populate them
  for osd in `ls $expath` ; do
  for size in `ls $expath/$osd` ; do
  for bench in `ls $expath/$osd/$size` ; do
  for client in `ls $expath/$osd/$size/$bench` ; do
    f="$expath/$osd/$size/$bench/$client"

    if [ $bench = "write" ] ; then
      tp=`grep 'Bandwidth (MB/sec):' $f | sed 's/Bandwidth (MB\/sec): *//'`
      lt=`grep 'Average Latency:' $f | sed 's/Average Latency: *//'`
      echo "$size, $tp" >> $throughput
      echo "$size, $lt" >> $latency
      echo "$size, $osd, $tp" >> $scale
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
                      -e "experiment='$EXP'" \
                      /script/plot.gp
fi

exit 0
