#!/bin/bash

CaseName=BG_iteration_1_switch_to_CAM54_midstream
SD=/glade/scratch/jfyke/archive/$CaseName/cpl/hist

for yr in `seq -f '%04g' 1 1`; do 
    for m in `seq -f '%02g' 1 12`; do
       for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do       
	  fname_out=$SD/$CaseName.cpl.$ftype.$yr-$m.nc
	  echo $fname_out
	  if [ -f $fname_out ]; then
	     rm $fname_out
	  fi
	  ncrcat -O $SD/$CaseName.cpl.$ftype.$yr-$m-*.nc $fname_out
       done
    done
done
