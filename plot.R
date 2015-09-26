importAndInstallIfMissing <- function(pkgname) {
    if(pkgname %in% rownames(installed.packages()) == FALSE) {
        install.packages(pkgname, repos="http://cran.cnr.berkeley.edu")
    }
    library(pkgname,character.only=TRUE)
}

importAndInstallIfMissing("ggplot2")
importAndInstallIfMissing("data.table")

args <- commandArgs(trailingOnly = TRUE)

if(length(args) != 3) {
  stop("Expecting 3 arguments: CSV file name, num. of observations and output folder")
}

# load CSV file
df = read.csv(args[1], header = TRUE)
n = as.numeric(args[2])
outfolder = args[3]

# turn it into a table
dt <- data.table(df)

# sort by num_osd
dt <- dt[order(num_osd),]

print(dt)

# get sum over all clients (group by [num_osd,rep] and sum)
dtsum <- dt[, list(avg_throughput=sum(avg_throughput),
                   stdev_throughput=sum(stdev_throughput)),
              by=list(num_osd,rep)]

# get the mean/stderr over all repetitions and observations
agg <- as.data.frame(
         dtsum[, list(avg_throughput=mean(avg_throughput),
                   stdev_throughput=mean(stdev_throughput)/sqrt(n)),
              by =list(num_osd)])

print("----------")
# plot
ppi <- 300
print(agg)
png(paste(outfolder,"/output.png",sep=""), width=6*ppi, height=6*ppi, res=ppi)
print(
  ggplot(
    agg, aes(x=num_osd, y=avg_throughput, group=1)) +
    geom_errorbar(aes(ymin=avg_throughput-stdev_throughput, ymax=avg_throughput+stdev_throughput, width=.1)) +
    geom_point() +
    geom_line() +
    scale_x_continuous(limits=c(0,max(df$num_osd)+1), breaks=seq(0,max(df$num_osd)+1,1)) +
    scale_y_continuous(limits=c(0,140), breaks=seq(0,140,10)))
garbage <- dev.off()
