#!/bin/bash

t=7
let tm1=t-1

BG_CaseName_Root=BG_iteration_
JG_CaseName_Root=JG_iteration_
BG_Restart_Year_Short=40
BG_Restart_Year=`printf %04d $BG_Restart_Year_Short`
BG_Forcing_Year_Start=10
let BG_Forcing_Year_End=BG_Restart_Year_Short-1

#Set name of simulation
CaseName=$JG_CaseName_Root"$t"
PreviousBGCaseName="$BG_CaseName_Root""$tm1"
JG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
BG_tm1_ArchiveDir=/glade/scratch/jfyke/$PreviousBGCaseName/run



for m in `seq -f '%02g' 1 12`; do
  echo $m
  flist=""
  for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do
    flist="$flist $BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.h.$yr-$m.nc"
  done    
  ncra -F -v SALT -d z_t,1,1,1 $flist SSS_$m.nc

done

ncrcat SSS_* climo_SSS.nc
