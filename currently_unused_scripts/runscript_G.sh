#!/bin/bash

D=$PWD

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=7
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_
    BG_Restart_Year_Short=40
    BG_Restart_Year=`printf %04d $BG_Restart_Year_Short`
    BG_Forcing_Year_Start=10
    let BG_Forcing_Year_End=BG_Restart_Year_Short-1
    
    #Set name of simulation
    CaseName=G_test

###set project code
    ProjCode=P93300601
    
###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm1_5_beta06
    #Create new experiment setup
    $CCSMRoot/cime/scripts/create_newcase -case $D/$CaseName \
                                	  -compset G \
					  -res f09_g16 \
					  -mach yellowstone\
					  -project $ProjCode

    cd $CaseName
    ./case.setup
