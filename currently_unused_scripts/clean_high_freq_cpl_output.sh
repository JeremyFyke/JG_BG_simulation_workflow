#!/bin/bash

PreviousBGCaseName=BG_iteration_2
RunDir=$PreviousBGCaseName/RunDir

BG_Forcing_Year_Start=1
BG_Forcing_Year_End=41

for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do 
   for m in `seq -f '%02g' 1 12`; do
      for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do
          fname_out=$RunDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m.nc
	  if [ -f $fname_out ]; then  #Safety check: only clean if concatenated file exists.
	      for fname in `ls $RunDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc`; do 
	           if [ -f $fname ]; then
	              #ls $fname
	              rm -v $fname
		   fi
	      done
	  fi	  
      done	   
   done
done
