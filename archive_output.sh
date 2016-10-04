#!/bin/bash

S=/glade/scratch/jfyke
#for i in JG BG; do
for i in JG; do
   for n in 7_restoring; do
       D="$i"_iteration_"$n"
       echo "Submitting archiving job for" $S/$D/run
       if [ -d $S/$D ]; then
          bsub -n 1 -q hpss -W 05:00 -P P93300301 htar -cv -f "$D".tar $S/$D/run
       else
          echo "Error: directory does not exist: " $S/$D/run
       fi
   done
done
