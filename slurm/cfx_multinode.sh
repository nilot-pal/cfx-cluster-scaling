#!/bin/bash
# CFX on Slurm, multi-node. Sanitised: account, paths and case name replaced.
#
# The three lines that mattered most in the benchmark study are marked.

#SBATCH --job-name=cfx_scaling
#SBATCH --account=<your_allocation>
#SBATCH --partition=normal_q
#SBATCH --nodes=4                    # <-- the variable in the multi-node study
#SBATCH --ntasks-per-node=64
#SBATCH --cpus-per-task=1            # one core per MPI rank, no OpenMP threading
#SBATCH --time=3-00:00:00
#SBATCH --exclusive                  # <-- REQUIRED for repeatable timings

module reset
module load ANSYS/2024R1

export CFX5_START_METHOD="Open MPI Distributed Parallel"

# Build the host list Slurm actually gave us, in the form CFX expects:
#   host1*ntasks,host2*ntasks,...
HOSTLIST=$(scontrol show hostnames "$SLURM_JOB_NODELIST" \
           | awk -v n="$SLURM_NTASKS_PER_NODE" '{printf "%s*%s,", $1, n}' | sed 's/,$//')
echo "host list: $HOSTLIST"

# Memory flags size the general solver pools. They do NOT bound particle-track
# bookkeeping, which grows dynamically with breakage - see notes/.
cfx5solve \
  -def   "case.def" \
  -part  "$SLURM_NTASKS" \
  -parallel -par-host-list "$HOSTLIST" \
  -start-method "$CFX5_START_METHOD" \
  -size 1.5 -size-mms 1.5 \
  -batch

# Note on rank counts: certain values triggered solver error 255 on multi-node
# jobs. Counts that are not powers of two were reliable - 36 rather than 32,
# 68 rather than 64. Cause never established.
