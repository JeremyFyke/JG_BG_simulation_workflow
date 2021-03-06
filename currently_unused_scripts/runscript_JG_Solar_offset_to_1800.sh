#!/bin/bash

D=$PWD

#NOTE: ice acceleration is ON
#NOTE: TODO: stop all mosart .h. files from being copied over during wildcard copy

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=4
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_
    BG_Restart_Year_Short=16
    BG_Restart_Year=`printf %04d $BG_Restart_Year_Short`
    BG_Forcing_Year_Start=5
    let BG_Forcing_Year_End=BG_Restart_Year_Short-1
    
    #Need to also change DATM_CPLHIST_YR_[START/END] below.  I think 'align' needs to be same as BG_Restart_Year, but without padded zeros
    #Set name of simulation
    CaseName="$JG_CaseName_Root""$t"_Solar_offset_to_1800
    PreviousBGCaseName="$BG_CaseName_Root""$tm1"
    JG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
    BG_tm1_ArchiveDir=/glade/scratch/jfyke/$PreviousBGCaseName/run

###set project code
    ProjCode=P93300301
    
###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm1_5_beta06
    #Create new experiment setup
    $CCSMRoot/cime/scripts/create_newcase -case $D/$CaseName \
                                	  -user_compset 1850_DATM%S1850_CLM50_CICE_POP2_MOSART_CISM2_SWAV \
					  -user_pes_setby allactive \
					  -res f09_g16_gl4 \
					  -mach yellowstone\
					  -project $ProjCode

    #Change directories into the new experiment case directory
    cd $D/$CaseName

    ./xmlchange NTASKS_ATM=30
    ./xmlchange NTASKS_CPL=930
    ./xmlchange NTASKS_GLC=1440
    ./xmlchange NTASKS_ICE=300
    ./xmlchange NTASKS_LND=630
    ./xmlchange NTASKS_OCN=480
    ./xmlchange NTASKS_ROF=630
    ./xmlchange NTASKS_WAV=1

    ./xmlchange ROOTPE_ATM=930
    ./xmlchange ROOTPE_CPL=0
    ./xmlchange ROOTPE_GLC=0
    ./xmlchange ROOTPE_ICE=630
    ./xmlchange ROOTPE_LND=0
    ./xmlchange ROOTPE_OCN=960
    ./xmlchange ROOTPE_ROF=0
    ./xmlchange ROOTPE_WAV=0
    
#     ./xmlchange NTASKS_ATM=15
#     ./xmlchange NTASKS_CPL=465
#     ./xmlchange NTASKS_GLC=720
#     ./xmlchange NTASKS_ICE=150
#     ./xmlchange NTASKS_LND=315
#     ./xmlchange NTASKS_OCN=240
#     ./xmlchange NTASKS_ROF=315
#     ./xmlchange NTASKS_WAV=1
# 
#     ./xmlchange ROOTPE_ATM=465
#     ./xmlchange ROOTPE_CPL=0
#     ./xmlchange ROOTPE_GLC=0
#     ./xmlchange ROOTPE_ICE=315
#     ./xmlchange ROOTPE_LND=0
#     ./xmlchange ROOTPE_OCN=480
#     ./xmlchange ROOTPE_ROF=0
#     ./xmlchange ROOTPE_WAV=0    
    

    ./xmlchange RUN_TYPE='hybrid'
    ./xmlchange RUN_REFCASE="$PreviousBGCaseName"
    ./xmlchange RUN_REFDATE="$BG_Restart_Year"-01-01

    ./xmlchange DATM_CPLHIST_CASE="$PreviousBGCaseName"
    ./xmlchange DATM_MODE='CPLHIST_JG'
    
    ./xmlchange DATM_CPLHIST_YR_START=$BG_Forcing_Year_Start
    ./xmlchange DATM_CPLHIST_YR_END=$BG_Forcing_Year_End
    ./xmlchange DATM_CPLHIST_YR_ALIGN=$BG_Forcing_Year_Start

    ./xmlchange CPL_ALBAV='false'
    ./xmlchange CPL_EPBAL='off'

    ./case.setup				      

###configure archiving
    ./xmlchange DOUT_S=FALSE

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

###concatenate monthly forcing files to expected location
    
    for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do 
	for m in `seq -f '%02g' 1 12`; do
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do       
	      fname_out=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m.nc
	      if [ -f $fname_out ]; then
	         echo 'NOT Concatenating ' $fname_out ': already exists.'
	      else
	         echo 'Concatenating ' $fname_out
	         ncrcat -O $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc $fname_out &
              fi
	   done
	   wait
	done
    done
    
###configure datm streams manually (mostly this is to force a no-read of topo and presaero, which I can't easily disable
    echo 'dtlimit = 3.0,3.0,3.0,3.0,3.0' > user_nl_datm
    echo "domainfile='/glade/u/cesm-scripts/liwg/Coupled_BG_JG_Spinup/JG_datm_stream_templates/domain_data_JGF_270416.nc'" >> user_nl_datm
    echo  "fillalgo = 'nn','nn','nn','nn','nn'" >> user_nl_datm
    echo   "fillmask = 'nomask','nomask','nomask','nomask','nomask'" >> user_nl_datm
    echo   "mapalgo = 'bilinear','bilinear','bilinear','bilinear','bilinear'" >> user_nl_datm
    echo   "mapmask = 'nomask','nomask','nomask','nomask','nomask'" >> user_nl_datm
    echo   "streams = 'datm.streams.txt.CPLHIST_JG.Solar 1 $BG_Forcing_Year_Start $BG_Forcing_Year_End', 'datm.streams.txt.CPLHIST_JG.Winds 1 $BG_Forcing_Year_Start $BG_Forcing_Year_End', 'datm.streams.txt.CPLHIST_JG.Precip 1 $BG_Forcing_Year_Start $BG_Forcing_Year_End', 'datm.streams.txt.CPLHIST_JG.nonSolarNonPrecip 1 $BG_Forcing_Year_Start $BG_Forcing_Year_End', 'datm.streams.txt.CPLHIST_JG.Daily 1 $BG_Forcing_Year_Start $BG_Forcing_Year_End'" >> user_nl_datm
    echo   "taxmode = 'cycle','cycle','cycle','cycle','cycle'" >> user_nl_datm
    echo   "tintalgo = 'linear','linear','nearest','linear','linear'" >> user_nl_datm

####copy in BHLV downscaling fix and switch to bilinear LND2GLC mapping to override bad conservative downscaling
    cp $D/SourceMods/map_lnd2glc_mod.F90 SourceMods/src.drv
    cp $D/SourceMods/seq_domain_mct.F90 SourceMods/src.drv #suppress fatal error due to domain fail on non-conservative remapping read
    ./xmlchange LND2GLC_FMAPNAME="cpl/gridmaps/fv0.9x1.25/map_fv0.9x1.25_TO_gland4km_blin.150514.nc"

####copy over JG restart files from previous BG run
    GLOBIGNORE=*.cam.*:rpointer.atm #Don't copy over any atmospheric restart stuff.
    #cp $BG_tm1_ArchiveDir/rest/0002-01-01-00000/* $JG_t_RunDir
    cp $BG_tm1_ArchiveDir/rpointer.* $JG_t_RunDir
    cp $BG_tm1_ArchiveDir/$PreviousBGCaseName.*r*$BG_Restart_Year* $JG_t_RunDir
    cp $BG_tm1_ArchiveDir/$PreviousBGCaseName.cism.h."$BG_Restart_Year"-01-01-00000.nc $JG_t_RunDir 
    cp $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.hi."$BG_Restart_Year"-01-01-00000.nc $JG_t_RunDir    
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
    ./xmlchange RESUBMIT=0
    ./xmlchange JOB_QUEUE='premium'
    ./xmlchange JOB_WALLCLOCK_TIME='00:40'
    ./xmlchange PROJECT="$ProjCode"

###make some soft links for convenience 
    ln -sf $JG_t_RunDir RunDir
    ln -sf /glade/scratch/jfyke/archive/$CaseName ArchiveDir

###build, submit
    ./case.build
    ./case.submit





