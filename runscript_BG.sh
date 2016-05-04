#!/bin/bash

D=$PWD

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=1
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_

    BG_Restart_Year=0002
    JG_Restart_Year=0102

    CaseName=$BG_CaseName_Root$t
    BG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
    JG_t_ArchiveDir=/glade/scratch/jfyke/archive/$JG_CaseName_Root$t
    BG_tm1_ArchiveDir=/glade/scratch/jfyke/archive/$BG_CaseName_Root$tm1

###set up model
    remove_runs.sh $CaseName
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
    ./xmlchange RUN_REFCASE=$JG_CaseName_Root$t
    ./xmlchange RUN_REFDATE="$JG_Restart_Year"-01-01  

    ./case.setup
   
###enable custom coupler output
    #Copy in necessary mods and settings to enable necessary coupler output for subsequent JG run
    cp $D/SourceMods/cesm_comp_mod.F90 SourceMods/src.drv
    cp $D/SourceMods/seq_infodata_mod.F90 SourceMods/src.share
    echo 'histaux_a2x3hr = .true.' > user_nl_cpl
    echo 'histaux_a2x24hr = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hri = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hr = .true.' >> user_nl_cpl

####copy in BHLV downscaling fix and switch to bilinear LND2GLC mapping to override bad conservative downscaling
    cp $D/SourceMods/map_lnd2glc_mod.F90 SourceMods/src.drv
    ./xmlchange LND2GLC_FMAPNAME="cpl/gridmaps/fv0.9x1.25/map_fv0.9x1.25_TO_gland4km_blin.150514.nc"

###configure CAM
    #./xmlchange CAM_CONFIG_OPTS="-phys cam5.4"

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

###copy all but CAM restarts over from end of JG simulation, and CAM restarts from previous BG simulation
    cp -v $JG_t_ArchiveDir/rest/$JG_Restart_Year-01-01-00000/* $BG_t_RunDir
    cp -v $BG_tm1_ArchiveDir/rest/$BG_Restart_Year-01-01-00000/*.cam.* $BG_t_RunDir
    cp -v $BG_tm1_ArchiveDir/rest/$BG_Restart_Year-01-01-00000/rpointer.atm $BG_t_RunDir
    
###set component-specific restarting tweaks that aren't handled by default scripts for this scenario
    #CAM
    #overwrite default script-generated restart info with custom values, to represent the migrated CAM restart file
        echo "bnd_topo='$BG_t_RunDir/$BG_CaseName_Root$tm1.cam.r.$BG_Restart_Year-01-01-00000.nc'" > user_nl_cam
        echo "ncdata='$BG_t_RunDir/$BG_CaseName_Root$tm1.cam.i.$BG_Restart_Year-01-01-00000.nc'" >> user_nl_cam
    #for a hybrid run, tack on landm_coslat, landfrac to cam.r. (since this is being used as the topography file)
        DataSourceFile=/glade/p/cesmdata/cseg/inputdata/atm/cam/topo/fv_0.9x1.25-gmted2010_modis-cam_fv_smooth-intermediate_ncube3000-no_anisoSGH_c151029.nc
        ncks -A -v LANDM_COSLAT,LANDFRAC $DataSourceFile $BG_t_RunDir/$BG_CaseName_Root$tm1.cam.r.$BG_Restart_Year-01-01-00000.nc

    #CICE
    #overwrite default script-generated ice_ice file name (bug in setup scripts?)
        echo "ice_ic='$BG_t_RunDir/$JG_CaseName_Root$t.cice.r.$JG_Restart_Year-01-01-00000.nc'" > user_nl_cice

###configure submission length and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange RESUBMIT=0
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='04:00'
    ./xmlchange PROJECT='P93300301'    

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir
    ArchiveDir=/glade/scratch/jfyke/archive/$CaseName
    ln -s $ArchiveDir ArchiveDir

###build and submit
./case.build

###run dynamic topography update to bring CAM topography up to JG-generated topography before starting
cd $CAM_topo_regen_dir
./CAM_topo_regen.sh
cd $D/$CaseName

./case.submit







