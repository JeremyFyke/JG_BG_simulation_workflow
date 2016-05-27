#!/bin/bash

D=$PWD

t=4
let tm1=t-1

BG_CaseName_Root=BG_iteration_
BG_Restart_Year_Short=15
BG_Restart_Year=0015

CaseName=$BG_CaseName_Root"$t"_rewind_test
PreviousBGCaseName="$BG_CaseName_Root""$tm1"

BG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
BG_tm1_ArchiveDir=/glade/scratch/jfyke/archive/$PreviousBGCaseName
BG_tm1_RunDir=/glade/scratch/jfyke/$PreviousBGCaseName/run   

###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm1_5_beta05
    #Create new experiment setup
    $CCSMRoot/cime/scripts/create_newcase -case $D/$CaseName \
					  -user_compset 1850_CAM5_CLM50_CICE_POP2_MOSART_CISM2_SWAV \
					  -user_pes_setby allactive \
					  -res f09_g16_gl4 \
					  -mach yellowstone\
					  -project P93300301
    #Change directories into the new experiment case directory
    cd $D/$CaseName
    
    ./xmlchange RUN_TYPE='hybrid'

    #Set primary restart-gathering names
    ./xmlchange RUN_REFCASE=$BG_CaseName_Root$tm1
    ./xmlchange RUN_REFDATE="$BG_Restart_Year"-01-01  

    ./case.setup

####copy in BHLV downscaling fix and switch to bilinear LND2GLC mapping to override bad conservative downscaling
    cp $D/SourceMods/map_lnd2glc_mod.F90 SourceMods/src.drv
    ./xmlchange LND2GLC_FMAPNAME="cpl/gridmaps/fv0.9x1.25/map_fv0.9x1.25_TO_gland4km_blin.150514.nc"

###configure CAM
    ./xmlchange CAM_CONFIG_OPTS="-phys cam5.4"
    
###configure CISM2  
    echo 'history_frequency=1' > user_nl_cism
    echo 'which_ho_babc=4' >> user_nl_cism
    echo 'which_ho_approx=4' >> user_nl_cism
    echo 'which_ho_gradient=0' >> user_nl_cism
    echo 'which_ho_gradient_margin=0' >> user_nl_cism
    echo 'which_ho_precond=1' >> user_nl_cism

    echo 'evolution=3' >> user_nl_cism
    echo 'which_ho_assemble_beta=0' >> user_nl_cism
    echo 'which_ho_flotation_function=1' >> user_nl_cism
    echo 'basal_mass_balance=1' >> user_nl_cism
    echo 'temp_init=2' >> user_nl_cism
    echo 'calving_domain=1' >> user_nl_cism
    echo 'which_ho_sparse=3' >> user_nl_cism
    echo 'which_ho_assemble_bfric=1' >> user_nl_cism
    echo 'glissade_maxiter=50' >> user_nl_cism
    
###configure archiving
    ./xmlchange DOUT_S=FALSE

####copy over BG restart files from previous BG run    
    cp $BG_tm1_ArchiveDir/rpointer.* $BG_t_RunDir
    sed -i s/16/15/g $BG_t_RunDir/rpointer.*
    cp $BG_tm1_ArchiveDir/$PreviousBGCaseName.*r*$BG_Restart_Year* $BG_t_RunDir
    cp $BG_tm1_ArchiveDir/$PreviousBGCaseName.cism.h."$BG_Restart_Year"-01-01-00000.nc $BG_t_RunDir 
    cp $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.hi."$BG_Restart_Year"-01-01-00000.nc $BG_t_RunDir      

###configure submission length, diagnostic CPL history output, and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1
    ./xmlchange RESUBMIT=0
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='04:00'
    ./xmlchange PROJECT='P93300301'

###make some soft links for convenience 
    ln -sf $BG_t_RunDir RunDir
    ln -sf /glade/scratch/jfyke/archive/$CaseName ArchiveDir

###build, submit
    ./case.build
    ./case.submit
