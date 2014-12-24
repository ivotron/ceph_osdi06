#!/bin/bash
#
# Script to execute scalability experiment of OSDI paper (Figure 8). It 
# optionally generates a png file out of the experiment results.
#
# The RUN_EXP variable determines whether to execute the experiment. The 
# GENERATE_FIGURES variable determines whether to generate the figures from 
# radosbench output.
#
# ROOT_FOLDER is the path where folders cephconf/ and results/ are placed. They 
# should be shared among all docker hosts over NFS and be located on the same 
# path on each host.
#
# Using maestro-ng and the maestro.yaml file, it deploys ceph with multiple 
# configurations (e.g. varying the number of OSD nodes). The monitor creates or 
# re-uses the configuration information stored in CEPHCONF. OSD nodes read the 
# Ceph configuration from this folder.
#
# Variables that control the experiment:
#
#   * MIN_NUM_OSD - minimum number of OSD nodes to begin
#
#   * MAX_NUM_OSD - largest cluster size to test with
#
#   * PG_PER_OSD - number of placement groups per OSD node
#
#   * RESULTS_FOLDER - the output of radosbench is stored here, organized as:
#
#       $ROOT_FOLDER/$RESULTS_FOLDER/$EXP/$pgs/$num_osd/$size/$test/$rep
#
#     where:
#        EXP - name of the experiment
#        pgs - number of placement groups
#        num_osd - number of OSD nodes used in that execution
#        size - object size used
#        test - write | seq | rand
#        rep - repetition of the experiment (ranging from [1-5])

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
  echo " -m : Maximum number of OSDs (default: 2)."
  echo " -n : Experiment name (default: time-based [e.g. $EXP])."
  echo " -i : Initial number of OSDs (default: 1)."
  echo " -p : Placement groups per OSD (default: 128)."
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
    echo $($c health) >> $f/health 
    sleep 1
    echo -n "."
  done
  echo ""
}

while getopts ":e:f:h:i:m:n:p" OPTION
do
  case ${OPTION} in
  e)
    RUN_EXP="${OPTARG}"
    ;;
  f)
    GENERATE_FIGURES="${OPTARG}"
    ;;
  h)
    usage
    ;;
  i)
    MIN_NUM_OSD="${OPTARG}"
    ;;
  m)
    MAX_NUM_OSD="${OPTARG}"
    ;;
  n)
    EXP="${OPTARG}"
    ;;
  p)
    PG_PER_OSD="${OPTARG}"
    ;;
  esac
done

####################
# Set default values
####################

if [ ! -n "$ROOT_FOLDER" ] ; then
  ROOT_FOLDER="$PWD"
fi
if [ ! -n "$RUN_EXP" ] ; then
  RUN_EXP="y"
fi
if [ ! -n "$GENERATE_FIGURES" ]; then
  GENERATE_FIGURES="y"
fi
if [ ! -n "$CEPHCONF" ]; then
  CEPHCONF=$ROOT_FOLDER/cephconf
fi
if [ ! -n "$RESULTS_FOLDER" ]; then
  RESULTS_FOLDER=results
fi
if [ ! -n "${MAX_NUM_OSD}" ]; then
  MAX_NUM_OSD=2
fi
if [ ! -n "${MIN_NUM_OSD}" ]; then
  MIN_NUM_OSD=1
fi
if [ ! -n "$PER_ROUND_OSD_INCREMENT" ]; then
  PER_ROUND_OSD_INCREMENT=1
fi
if [ ! -n "$PG_PER_OSD" ]; then
  PG_PER_OSD=128
fi

###################
# docker basics
###################

# check if we can execute docker
docker_exists=`type -P docker &>/dev/null && echo "found" || echo "not found"`

if [ $docker_exists = "not found" ]; then
  echo "ERROR: can't execute docker, make sure it's reachable via PATH"
  exit 1
fi

###############
# Run experiment
###############

# Executes write benchmarks from n=1 to MAX_NUM_OSD with replication factor
# 1 and 4m objects. This corresponds to figure 8.
#
# TODO: When n=THROUGHPUT_EXP_AT, object size ranges from 4k to 4m, which 
# corresponds to the red line in figures 5,6. Read (seq) benchmarks are also 
# executed, which are used for figure 7.

if [ $RUN_EXP = "y" ] ; then

# check if maestro runs OK
m="docker run --rm=true -v `pwd`:/data ivotron/maestro-ng:0.2.4-dev"

$m status

if [ $? != "0" ] ; then
  echo "ERROR: can't execute maestro container"
  exit 1
fi

# alias
c="docker run --rm=true -v $CEPHCONF:/etc/ceph ivotron/ceph-base:0.87.1 /usr/bin/ceph"

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

  if [ "$curr_osd" -lt "$MIN_NUM_OSD" ] ; then
    curr_osd=$(($curr_osd + 1))
    continue
  fi

  # create pool
  pgs=$(($PG_PER_OSD * $curr_osd))

  $c osd pool create test $pgs $pgs

  # set replication factor to 1
  $c osd pool set test size 1

  # wait for it
  ceph_health

  sleep 10

  rep=1
  while [ $rep -le 3 ] ; do
  for size in $SIZE; do

    f="$ROOT_FOLDER/$RESULTS_FOLDER/$EXP/$pgs/$curr_osd/$size/write/$rep"
    mkdir -p $f

    SECS=60
    SIZE=4194304
    EXP_TYPE="write"
    THREADS=16

    $m start ceph-radosbench

    if [ $? != "0" ] ; then
      echo "ERROR: can't initialize radosbench services"
      exit 1
    fi

    echo "" > $f/health

    wait_for_radosbench

    ceph_health

    # check if cluster misbehaved
    num_warns=`grep "HEALTH_WARN" $f/health | wc -l`

    # get to next repetition iff there were no warnings
    if [ $num_warns -eq 0 ] ; then
      rep=$(($rep + 1))
      rm $f/health
    fi

  done
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
  expath=$RESULTS_FOLDER/$EXP
  throughput=${expath}_per-osd-write-throughput.csv
  latency=${expath}_per-osd-write-latency.csv
  rw=${expath}_per-osd-rw-throughput.csv
  scale=${expath}_per-osd-scalable-throughput.csv

  # create files
  echo "num_osd, size, repetition, throughput_avg, throughput_std" > $throughput
  echo "num_osd, size, repetition, latency_avg, latency_std" > $latency
  echo "num_osd, size, repetition, throughput_avg, throughput_std" > $scale

  # populate them
  for pg in `ls $ROOT_FOLDER/$expath` ; do
  for osd in `ls $ROOT_FOLDER/$expath/$pg/` ; do
  for size in `ls $ROOT_FOLDER/$expath/$pg/$osd` ; do
  for bench in `ls $ROOT_FOLDER/$expath/$pg/$osd/$size` ; do
  for rep in `ls $ROOT_FOLDER/$expath/$pg/$osd/$size/$bench` ; do
    f="$ROOT_FOLDER/$expath/$pg/$osd/$size/$bench/$rep"

    if [ $bench = "write" ] ; then
      tp_std=`grep 'Stddev Bandwidth:' $f/out | sed 's/Stddev Bandwidth: *//'`
      lt_std=`grep 'Stddev Latency:' $f/out | sed 's/Stddev Latency: *//'`
      tp_avg=`grep 'Bandwidth (MB/sec):' $f/out | sed 's/Bandwidth (MB\/sec): *//'`
      lt_avg=`grep 'Average Latency:' $f/out | sed 's/Average Latency: *//'`
    fi

    echo "$pg,$osd,$size,$rep,$tp_avg,$tp_std" >> $throughput
    echo "$pg,$osd,$size,$rep,$lt_avg,$lt_std" >> $latency
    echo "$pg,$osd,$size,$rep,$tp_avg,$tp_std" >> $scale
  done
  done
  done
  done
  done

  # generate the figures (png files)

  # figure 8
  docker run \
      --rm=true \
      -v $ROOT_FOLDER:/mnt \
      ivotron/r-with-pkgs:3.1.2 /usr/bin/Rscript /mnt/plot.R /mnt/$scale

fi # GENERATE_FIGURES

exit 0
