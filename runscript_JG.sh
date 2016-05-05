#!/bin/bash

D=$PWD

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=2
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_
    BG_Restart_Year=0002
    #Need to also change DATM_CPLHIST_YR_[START/END/ALIGN] below.  I think 'align' needs to be same as BG_Restart_Year, but without padded zeros
    #Set name of simulation
    CaseName=$JG_CaseName_Root$t
    PreviousBGCaseName="$BG_CaseName_Root""$tm1"_switch_to_CAM54_midstream
    JG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
    BG_tm1_ArchiveDir=/glade/scratch/jfyke/archive/$PreviousBGCaseName
    
###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm1_5_beta05
    #Create new experiment setup
    $CCSMRoot/cime/scripts/create_newcase -case $D/$CaseName \
                                	  -user_compset 1850_DATM%S1850_CLM50_CICE_POP2_MOSART_CISM2_SWAV \
					  -user_pes_setby allactive \
					  -res f09_g16_gl4 \
					  -mach yellowstone\
					  -project P93300601

    #Change directories into the new experiment case directory
    cd $D/$CaseName

    ./xmlchange NTASKS_ATM=15
    ./xmlchange NTASKS_CPL=465
    ./xmlchange NTASKS_GLC=720
    ./xmlchange NTASKS_ICE=150
    ./xmlchange NTASKS_LND=315
    ./xmlchange NTASKS_OCN=240
    ./xmlchange NTASKS_ROF=315
    ./xmlchange NTASKS_WAV=1

    ./xmlchange ROOTPE_ATM=465
    ./xmlchange ROOTPE_CPL=0
    ./xmlchange ROOTPE_GLC=0
    ./xmlchange ROOTPE_ICE=315
    ./xmlchange ROOTPE_LND=0
    ./xmlchange ROOTPE_OCN=480
    ./xmlchange ROOTPE_ROF=0
    ./xmlchange ROOTPE_WAV=0

    ./xmlchange RUN_TYPE='hybrid'
    ./xmlchange RUN_REFCASE="$PreviousBGCaseName"
    ./xmlchange RUN_REFDATE="$BG_Restart_Year"-01-01

    ./xmlchange DATM_CPLHIST_CASE="$PreviousBGCaseName"
    ./xmlchange DATM_MODE='CPLHIST_JG'
    
    ./xmlchange DATM_CPLHIST_YR_START=1
    ./xmlchange DATM_CPLHIST_YR_END=1
    ./xmlchange DATM_CPLHIST_YR_ALIGN=2

    ./xmlchange CPL_ALBAV='false'
    ./xmlchange CPL_EPBAL='off'

    ./case.setup				      

###configure CISM2
    #Configure CISM2 run-time options.  
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

    #accelerate ice sheet
    echo 'ice_tstep_multiply=10' >> user_nl_cism 

###configure POP
    #Turn off precipitation scaling in POP for JG runs
    echo ladjust_precip=.false. > user_nl_pop

###configure datm streams manually (mostly this is to force a no-read of topo and presaero
    echo 'dtlimit = 3.0,3.0,3.0,3.0,3.0' > user_nl_datm
    echo "domainfile='/glade/u/cesm-scripts/liwg/Coupled_BG_JG_Spinup/JG_datm_stream_templates/domain_data_JGF_270416.nc'" >> user_nl_datm
    echo  "fillalgo = 'nn','nn','nn','nn','nn'" >> user_nl_datm
    echo   "fillmask = 'nomask','nomask','nomask','nomask','nomask'" >> user_nl_datm
    echo   "mapalgo = 'bilinear','bilinear','bilinear','bilinear','bilinear'" >> user_nl_datm
    echo   "mapmask = 'nomask','nomask','nomask','nomask','nomask'" >> user_nl_datm
    echo   'streams = "datm.streams.txt.CPLHIST_JG.Solar 2 1 1", "datm.streams.txt.CPLHIST_JG.Winds 2 1 1", "datm.streams.txt.CPLHIST_JG.Precip 2 1 1", "datm.streams.txt.CPLHIST_JG.nonSolarNonPrecip 2 1 1", "datm.streams.txt.CPLHIST_JG.Daily 2 1 1"' >> user_nl_datm
    echo   "taxmode = 'cycle','cycle','cycle','cycle','cycle'" >> user_nl_datm
    echo   "tintalgo = 'coszen','linear','nearest','linear','linear'" >> user_nl_datm

####copy in BHLV downscaling fix and switch to bilinear LND2GLC mapping to override bad conservative downscaling
    cp $D/SourceMods/map_lnd2glc_mod.F90 SourceMods/src.drv
    ./xmlchange LND2GLC_FMAPNAME="cpl/gridmaps/fv0.9x1.25/map_fv0.9x1.25_TO_gland4km_blin.150514.nc"

    GLOBIGNORE=*.cam.*:rpointer.atm #Don't copy over any atmospheric restart stuff.
    cp $BG_tm1_ArchiveDir/rest/0002-01-01-00000/* $JG_t_RunDir #TODO: update date to 0041 (or whatever full length+1 of BG run is)
    GLOBIGNORE=

###set component-specific restarting tweaks that aren't handled by default scripts for this scenario
    #CICE
    #overwrite default script-generated ice_ice file name (bug in setup scripts?)
    echo "ice_ic='$JG_t_RunDir/$PreviousBGCaseName.cice.r.$BG_Restart_Year-01-01-00000.nc'" > user_nl_cice

###configure submission length, diagnostic CPL history output, and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1
    ./xmlchange RESUBMIT=100
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='00:40'
    ./xmlchange PROJECT='P93300601'

###make some soft links for convenience 
    ln -sf $JG_t_RunDir RunDir
    ln -sf /glade/scratch/jfyke/archive/$CaseName ArchiveDir

###build, submit
    ./case.build
    ./case.submit





