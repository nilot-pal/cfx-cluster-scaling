# Dynamic memory and I/O growth in CFX particle tracking with breakage

Written to take to the university's HPC centre. The point of writing it this way was to arrive
with evidence and specific questions rather than "my job keeps dying", and to establish that I
had not yet spent the easy option, so the conversation could be about system limits instead of
about giving up resolution.

## The failure

ANSYS CFX 2024R1. Three-stage axial compressor, aerothermal flow plus Lagrangian particle
tracking with wall breakage. The flow solve is stable. With trajectory output enabled the job
eventually dies:

```
/PARTICLE/TRACK_INFO/PATCH_INFO/PT1
INSUFFICIENT MEMORY ALLOCATED
ACTION REQUIRED: Increase the integer stack memory size
```

The error points at particle-track bookkeeping, the integer stack and track-info structures,
not at the flow solver.

## Evidence

| | injected | grew to | track file | outcome |
|---|---|---|---|---|
| small, workstation | 1,000 | ~6,000 (6×) | 1.35 GB | completed |
| production, cluster | 500,000 | ~3.4 M (6.8×) | 444 GB before failure | killed |

Breakage multiplies particle count by a factor that is stable at roughly 6–7× across three orders
of magnitude of injection. It also extends particle lifetime, since fragments persist after the
parent would have left. Runtime cost therefore scales with **particle count × lifetime × history
retained per particle**, and all three move in the wrong direction at once.

## Why the solver's memory flags do not fix it

`cfx5solve` takes `-large`, `-size`, `-ni` and similar. Those were already necessary to stabilise
the aerothermal solve, and they do what they claim; they size the general solver memory pools.

They do not control particle multiplication, fragment lifetime, or how much trajectory history is
stored per particle. So this is not insufficient *static* allocation. It is dynamic growth in
bookkeeping that no static flag bounds, which is why raising the flags kept not working.

## The part that took longest to see

Memory pressure here is **per-rank, not per-node**.

Breakage is not uniform. It concentrates where impacts concentrate: blade surfaces, hub, shroud
so some partitions carry far more particles than others, and the trajectory bookkeeping scales
with the local population. The job fails when the first rank hits its own allocation limit, and
that can happen while aggregate node memory still looks fine.

Consequence: watching node-level memory tells you nothing useful. The diagnostic that matters is
per-rank peak RSS, and the mitigation that matters is fewer ranks per node: trading cores for
headroom per rank, which is the opposite of what you do for throughput.

Configuration at failure: 6 nodes × 64 ranks = 384 ranks, `--cpus-per-task=1`, ANSYS OpenMPI
distributed parallel.

## The I/O half

Track files reach hundreds of GB and are written incrementally, many small operations rather
than a few large ones.

On a cluster that is the expensive pattern. `/scratch`, `/home` and `/projects` all live on a
storage cluster reached over the network, so a stream of small sequential operations is dominated
by per-operation latency rather than by throughput. It is the failure mode that does not exist on
a workstation with a local SSD, which is exactly why nobody arriving from one anticipates it.

What follows from that:

- Moving between remote filesystems is worth **about 10%**. Not the answer.
- Writing to the compute node's own disk (`$TMPDIR`, `/localscratch/<jobid>`) is the change
  that matters.
- Multi-node makes that harder, not easier. Each node has its own `$TMPDIR`, so input must be
  broadcast to every node and output gathered back before the allocation ends, or it goes with
  the node.

## What I deliberately did not do first

Application-level mitigations were available throughout: inject fewer particles, weight them
statistically, terminate fragments on residence time, write trajectory history less often, or
record impact and breakage events instead of full tracks. The last of those is defensible on its
own merits, full trajectories are not needed for the result.

But every one of them trades away statistics, and I did not want to pay that before knowing
whether the infrastructure could carry the real workload. Establishing the system limit first
means the compromise, when it comes, is chosen rather than assumed.

Even a 20–30% increase in the failure boundary would have been worth having.
