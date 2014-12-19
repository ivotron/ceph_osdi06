set term png

if (!exists("folder")) print "ERROR: expecting variable 'folder'"; exit;
if (!exists("experiment")) print "ERROR: expecting variable 'experiment'"; exit;
if (!exists("maxosd")) print "ERROR: expecting variable 'maxosd'"; exit;

f=folder.'/'.experiment.'_per-osd-scalable-throughput.csv'
set output folder.'/'.experiment.'_scalable.png'
set xlabel "OSD Cluster Size"
set ylabel "Per-OSD Throughput (MB/s)"
set xrange [2:10]
set yrange [0:25]
plot f every::0::10 using 2:($2/$1) title 'crush' with lines smooth unique

/*f=folder.'/'.experiment.'_per-osd-write-latency.csv'*/
/*set output folder.'/'.experiment.'_latency.png'*/
/*set xlabel "Write Size (KB)"*/
/*set ylabel "Latency (ms)"*/
/*set xtics ( "4" 4096, "16" 16384, "64" 65536, "256" 262144, "1024" 1048576, "4096" 4194304)*/
/*set logscale x 2*/
/*set xrange [4096:4250000]*/
/*set yrange [0:1000]*/
/*plot f every::0::10  using 1:($2 * 1000) title 'no replication' with lines smooth unique*/

/*f=folder.'/'.experiment.'_per-osd-write-throughput.csv'*/
/*set output folder.'/'.experiment.'_throughput.png'*/
/*set xlabel "Write Size (KB)"*/
/*set ylabel "Per-OSD Throughput (MB/s)"*/
/*set xtics ( "4" 4096, "16" 16384, "64" 65536, "256" 262144, "1024" 1048576, "4096" 4194304)*/
/*set logscale x 2*/
/*set yrange [0:25]*/
/*plot f every::0::10  using 1:($2/maxosd) title 'no replication' with lines smooth unique*/
