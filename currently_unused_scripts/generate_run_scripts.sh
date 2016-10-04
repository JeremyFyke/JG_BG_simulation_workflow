#!/bin/bash

for t in {0..9}; do

   sed -i s/CaseName=JG_iteration_[0-9]*/CaseName=JG_iteration_$t/g ./setup_JG.sh
   source ./setup_JG.sh
   
   if ((t > 0 )); then 
      sed -i s/CaseName=BG_iteration_[0-9]*/CaseName=BG_iteration_$t/g ./setup_BG.sh
      source ./setup_BG.sh   
   fi
done
