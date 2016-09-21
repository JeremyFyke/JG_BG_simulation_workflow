#!/bin/bash

S=/glade/scratch/jfyke

for i in JG BG; do
   for n in 1 2 3 4 5 6; do
       D="$i"_iteration_"$n"
       echo "Removing restarts from" $S/$D/run
       rm -v $S/$D/run/*.r*.nc
   done
done
