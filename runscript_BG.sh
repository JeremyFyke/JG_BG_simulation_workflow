#!/bin/bash

D=$PWD

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=5
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_

    BG_Restart_Year=0040
    JG_Restart_Year=0035

    CaseName=$BG_CaseName_Root"$t"
    PreviousJGCaseName=$JG_CaseName_Root"$t"
    PreviousBGCaseName="$BG_CaseName_Root""$tm1"
       
    BG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
    JG_t_ArchiveDir=/glade/scratch/jfyke/archive/$PreviousJGCaseName
    JG_t_RunDir=/glade/scratch/jfyke/$PreviousJGCaseName/run
    BG_tm1_ArchiveDir=/glade/scratch/jfyke/archive/$PreviousBGCaseName
    BG_tm1_RunDir=/glade/scratch/jfyke/$PreviousBGCaseName/run   

###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm1_5_beta06
    #Create new experiment setup
    $CCSMRoot/cime/scripts/create_newcase -case $D/$CaseName \
					  -user_compset 1850_CAM5_CLM50_CICE_POP2_MOSART_CISM2_SWAV \
					  -user_pes_setby allactive \
					  -res f09_g16_gl4 \
					  -mach yellowstone\
					  -project P93300301
    #Change directories into the new experiment case directory
    cd $D/$CaseName

    ./xmlchange NTASKS_ATM=1728
    ./xmlchange NTASKS_CPL=1728
    ./xmlchange NTASKS_ESP=1728
    ./xmlchange NTASKS_GLC=1728
    ./xmlchange NTASKS_ICE=1392
    ./xmlchange NTASKS_LND=336
    ./xmlchange NTASKS_OCN=48
    ./xmlchange NTASKS_ROF=336
    ./xmlchange NTASKS_WAV=1
    ./xmlchange ROOTPE_ATM=0
    ./xmlchange ROOTPE_CPL=0
    ./xmlchange ROOTPE_ESP=0
    ./xmlchange ROOTPE_GLC=0
    ./xmlchange ROOTPE_ICE=336
    ./xmlchange ROOTPE_LND=0
    ./xmlchange ROOTPE_OCN=1728
    ./xmlchange ROOTPE_ROF=0
    ./xmlchange ROOTPE_WAV=0
   
    ./xmlchange RUN_TYPE='hybrid'
    #Set primary restart-gathering names
    ./xmlchange RUN_REFCASE=$JG_CaseName_Root$t
    ./xmlchange RUN_REFDATE="$JG_Restart_Year"-01-01  

    ./case.setup
   
###enable custom coupler output
    #Copy in necessary mods and settings to enable necessary coupler output for subsequent JG run
    cp $D/SourceMods/cesm_comp_mod.F90 SourceMods/src.drv
    cp $D/SourceMods/seq_infodata_mod.F90 SourceMods/src.share
    cp $D/SourceMods/seq_domain_mct.F90 SourceMods/src.drv    
    echo 'histaux_a2x3hr = .true.' > user_nl_cpl
    echo 'histaux_a2x24hr = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hri = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hr = .true.' >> user_nl_cpl

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

###configure topography updating    
    CAM_topo_regen_dir=$BG_t_RunDir/dynamic_atm_topog
    if [ ! -d $CAM_topo_regen_dir ]; then
       echo 'Checking out and building topography updater...'
       gmake=/usr/bin/gmake
       trunk=https://svn-ccsm-models.cgd.ucar.edu/tools/dynamic_cam_topography/trunk
       svn co $trunk $CAM_topo_regen_dir
       cd $CAM_topo_regen_dir/phis_smoothing/definesurf
       $gmake
       cd $CAM_topo_regen_dir/bin_to_cube
       $gmake
       cd $CAM_topo_regen_dir/cube_to_target
       $gmake
       cd $D/$CaseName
    fi
    data_assimilation_script=$CAM_topo_regen_dir/submit_topo_regen_script.sh
    ./xmlchange DATA_ASSIMILATION=TRUE
    ./xmlchange DATA_ASSIMILATION_CYCLES=1
    ./xmlchange DATA_ASSIMILATION_SCRIPT=$data_assimilation_script
    chmod u+x $data_assimilation_script

###configure archiving
    ./xmlchange DOUT_S=FALSE

###copy all but CAM restarts over from end of JG simulation, and CAM restarts from previous BG simulation
    
    f=$JG_t_RunDir/$PreviousJGCaseName.cice.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.cism.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.clm2.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.clm2.rh0."$JG_Restart_Year"-01-01-00000.nc;    cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.cpl.hi."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$JG_t_RunDir/$PreviousJGCaseName.cpl.r."$JG_Restart_Year"-01-01-00000.nc;       cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.datm.rs1."$JG_Restart_Year"-01-01-00000.bin;   cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.mosart.r."$JG_Restart_Year"-01-01-00000.nc;    cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$JG_t_RunDir/$PreviousJGCaseName.mosart.rh0."$JG_Restart_Year"-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }     
    f=$JG_t_RunDir/$PreviousJGCaseName.pop.r."$JG_Restart_Year"-01-01-00000.nc;       cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.pop.ro."$JG_Restart_Year"-01-01-00000;         cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }        
    f=$JG_t_RunDir/rpointer.drv;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.glc;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ice;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.lnd;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ocn.ovf;                                                  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ocn.restart;                                              cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.rof;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }

    #Ensure dates of non-CAM restarts are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$JG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.*

    #Then copy over CAM restarts
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.rs.$BG_Restart_Year-01-01-00000.nc; cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/rpointer.atm;                                               cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  

    #Ensure dates are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$BG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.atm
    
###set component-specific restarting tweaks that aren't handled by default scripts for this scenario
    #CAM
    #overwrite default script-generated restart info with custom values, to represent the migrated CAM restart file
	echo "bnd_topo='$BG_t_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc'" > user_nl_cam
        echo "ncdata='$BG_t_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc'" >> user_nl_cam
    #for a hybrid run, tack on landm_coslat, landfrac to cam.r. (since this is being used as the topography file)
        DataSourceFile=/glade/p/cesmdata/cseg/inputdata/atm/cam/topo/fv_0.9x1.25-gmted2010_modis-cam_fv_smooth-intermediate_ncube3000-no_anisoSGH_c151029.nc
        ncks -A -v LANDM_COSLAT,LANDFRAC $DataSourceFile $BG_t_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc

    #CICE
    #overwrite default script-generated ice_ice file name (bug in setup scripts?)
        echo "ice_ic='$BG_t_RunDir/$PreviousJGCaseName.cice.r.$JG_Restart_Year-01-01-00000.nc'" > user_nl_cice

###turn on CPL history output
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1

###configure submission length and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange RESUBMIT=39
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='04:00'
    ./xmlchange PROJECT='P93300301'    

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir
    ln -s /glade/scratch/jfyke/archive/$CaseName ArchiveDir

###copy esp_present=wav_present bugfix
    cp -vf $D/SourceMods/seq_rest_mod.F90 SourceMods/src.drv

###build
./case.build

###run dynamic topography update to bring CAM topography up to JG-generated topography before starting
cd $CAM_topo_regen_dir
export RUNDIR=$BG_t_RunDir
./CAM_topo_regen.sh
cd $D/$CaseName

###submit
./case.submit







