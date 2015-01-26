importAndInstallIfMissing <- function(pkgname) {
    if(pkgname %in% rownames(installed.packages()) == FALSE) {
        install.packages(pkgname, repos="http://cran.cnr.berkeley.edu")
    }
    library(pkgname,character.only=TRUE)
}

importAndInstallIfMissing("ggplot2")
importAndInstallIfMissing("data.table")

args <- commandArgs(trailingOnly = TRUE)

if(length(args) != 2) {
  stop("Expecting two arguments: CSV file name and num. of observations")
}

# load CSV file
df = read.csv(args[1], header = TRUE)
n = as.numeric(args[2])

# turn it into a table
dt <- data.table(df)

# sort by num_osd
dt <- dt[order(num_osd),]

print(dt)

# group by (num_osd, size) and get average and stderr of latency and throughput
agg <- as.data.frame(
         dt[, list(throughput_avg=mean(throughput_avg),
                   throughput_std=mean(throughput_std)/sqrt(n)),
              by = c("num_osd","size")])

print("----------")
# plot
ppi <- 300
print(agg)
png(paste(args[1],".png",sep=""), width=6*ppi, height=6*ppi, res=ppi)
print(
  ggplot(
    agg, aes(x=num_osd, y=throughput_avg, group=1)) +
    geom_errorbar(aes(ymin=throughput_avg-throughput_std, ymax=throughput_avg+throughput_std, width=.1)) +
    geom_point() +
    geom_line() +
    scale_x_continuous(limits=c(0,max(df$num_osd)+1), breaks=seq(0,max(df$num_osd)+1,1)) +
    scale_y_continuous(limits=c(0,140), breaks=seq(0,140,10)))
garbage <- dev.off()
