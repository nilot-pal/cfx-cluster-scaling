# Job scripts

`cfx_multinode.sh` is the multi-node script, sanitised: allocation, paths and case name removed.

Three things in it came out of the benchmark study rather than from documentation:

**`--exclusive` is not optional for benchmarking.** Wall-clock times fluctuated run to run until
jobs stopped sharing nodes with other tenants. Without it a scaling study measures the cluster's
background load as much as your own code.

**The host list has to be built from `$SLURM_JOB_NODELIST`.** CFX wants `host*ranks,host*ranks`,
which Slurm does not hand you directly.

**Rank counts that are powers of two were unreliable** on multi-node jobs, giving solver error
255. Using 36 instead of 32, or 68 instead of 64, worked consistently. I never found out why, and
I would not claim to understand it.

For the memory-heavy particle-tracking runs, the relevant lever is *fewer* ranks per node (more memory headroom per rank), which is the opposite of what you want for throughput. See
[`../notes/dynamic-memory-and-io.md`](../notes/dynamic-memory-and-io.md).
