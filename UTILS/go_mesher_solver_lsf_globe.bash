#!/bin/bash -v
#BSUB -o OUTPUT_FILES/%J.o
#BSUB -a mpich_gm
#BSUB -J go_mesher_solver_lsf

# this is the launch script to run a regular forward simulation
# on CITerra with the LSF scheduler
# assumes 'remap_lsf_machines.pl' is already in the $PATH
#  Qinya Liu, Caltech, May 2007

BASEMPIDIR=/scratch/$USER/DATABASES_MPI

echo "$LSB_MCPU_HOSTS" > OUTPUT_FILES/lsf_machines
echo "$LSB_JOBID" > OUTPUT_FILES/jobid

remap_lsf_machines.pl OUTPUT_FILES/lsf_machines >OUTPUT_FILES/machines

# create a directory for this job
shmux -M50 -Sall -c "mkdir -p /scratch/$USER; mkdir -p $BASEMPIDIR.$LSB_JOBID" - < OUTPUT_FILES/machines >/dev/null

# Set the local path in Par_file
sed -e "s:^LOCAL_PATH .*:LOCAL_PATH                      =  $BASEMPIDIR.$LSB_JOBID:" < DATA/Par_file > DATA/Par_file.tmp
mv DATA/Par_file.tmp DATA/Par_file


current_pwd=$PWD

mpirun.lsf  --gm-no-shmem --gm-copy-env $current_pwd/xmeshfem3D
mpirun.lsf --gm-no-shmem --gm-copy-env $current_pwd/xspecfem3D
