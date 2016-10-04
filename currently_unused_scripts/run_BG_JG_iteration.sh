#!/bin/bash

D=$PWD

t=1

let tm1=t-1
JG_t_CaseDir=/glade/u/cesm-scripts/liwg/Coupled_BG_JG_Spinup/JG_iteration_$t
BG_t_CaseDir=/glade/u/cesm-scripts/liwg/Coupled_BG_JG_Spinup/BG_iteration_$t
JG_t_RunDir=/glade/scratch/jfyke/JG_iteration_$t/run
BG_t_RunDir=/glade/scratch/jfyke/BG_iteration_$t/run
JG_t_ArchiveDir=/glade/scratch/jfyke/archive/BG_iteration_$t
BG_tm1_ArchiveDir=/glade/scratch/jfyke/archive/BG_iteration_$tm1

###RUN JG STEP###

GLOBIGNORE=*.cam.*:rpointer.atm
cp $BG_tm1_ArchiveDir/rest/0002-01-01-00000/* $JG_t_RunDir #TODO: update date to 0041 (or whatever full length+1 of BG run is)
GLOBIGNORE=

cd $JG_t_CaseDir   
./case.submit

###RUN BG STEP###
# 
# cp $JG_t_ArchiveDir/rest/0002-01-00000/* $BG_t_RunDir
# cp $BG_tm1_ArchiveDir/rest/0002-01-00000/*.cam.* $BG_t_RunDir
# cp $BG_tm1_ArchiveDir/rest/0002-01-00000/rpointer.atm $BG_t_RunDir    
# cd $BG_t_RunDir/dynamic_atm_topog
# source ./CAM_topo_regen.sh
# cd $BG_t_CaseDir 
# ./case.submit
