#!/bin/bash

D=$PWD

t=1

#Set name of your simulation
CaseName=BG_iteration_0

remove_runs.sh $CaseName

#Set the source code from which to build model
CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm1_5_beta05

#Create new experiment setup
 $CCSMRoot/cime/scripts/create_newcase -case $D/$CaseName \
				       -user_compset 1850_CAM5_CLM50_CICE_POP2_MOSART_CISM2_SWAV \
				       -user_pes_setby allactive \
				       -res f09_g16_gl4 \
				       -mach yellowstone\
				       -project P93300601

#Change directories into the new experiment case directory
cd $D/$CaseName

./case.setup

./xmlchange CAM_CONFIG_OPTS="-phys cam5.4"

#Copy in necessary mods and settings to enable necessary coupler output for JG run
cp $D/SourceMods/cesm_comp_mod.F90 SourceMods/src.drv
cp $D/SourceMods/seq_infodata_mod.F90 SourceMods/src.share
echo 'histaux_a2x3hr = .true.' > user_nl_cpl
echo 'histaux_a2x24hr = .true.' >> user_nl_cpl
echo 'histaux_a2x1hri = .true.' >> user_nl_cpl
echo 'histaux_a2x1hr = .true.' >> user_nl_cpl

#Configure CISM2 run-time options.  
echo 'history_frequency=1' > user_nl_cism
echo 'which_ho_babc=4' >> user_nl_cism
echo 'which_ho_approx=4' >> user_nl_cism
echo 'which_ho_gradient=0' >> user_nl_cism
echo 'which_ho_gradient_margin=0' >> user_nl_cism
echo 'which_ho_precond=1' >> user_nl_cism
echo "cisminputfile='/glade/scratch/jfyke/greenland_4km.glissade.10kyr.beta6.SSacab_c150415a_EH.nc'" >> user_nl_cism
echo 'evolution=3' >> user_nl_cism
echo 'which_ho_assemble_beta=0' >> user_nl_cism
echo 'which_ho_flotation_function=1' >> user_nl_cism
echo 'basal_mass_balance=1' >> user_nl_cism
echo 'temp_init=2' >> user_nl_cism
echo 'calving_domain=1' >> user_nl_cism
echo 'which_ho_sparse=3' >> user_nl_cism
echo 'which_ho_assemble_bfric=1' >> user_nl_cism
echo 'glissade_maxiter=50' >> user_nl_cism

#configure topography updating
RunDir=/glade/scratch/jfyke/$CaseName/run

CAM_topo_regen_dir=$RunDir/dynamic_atm_topog

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

#Copy in BHLV downscaling fix and switch to bilinear LND2GLC mapping to override bad conservative downscaling
cp $D/SourceMods/map_lnd2glc_mod.F90 SourceMods/src.drv
./xmlchange LND2GLC_FMAPNAME="cpl/gridmaps/fv0.9x1.25/map_fv0.9x1.25_TO_gland4km_blin.150514.nc"

./xmlchange STOP_OPTION='nyears'
./xmlchange STOP_N=1
./xmlchange RESUBMIT=10

ln -s $RunDir RunDir

ArchiveDir=/glade/scratch/jfyke/archive/$CaseName
ln -s $ArchiveDir ArchiveDir

./xmlchange JOB_QUEUE='regular'
./xmlchange JOB_WALLCLOCK_TIME='04:00'
./xmlchange PROJECT='P93300301'

./case.build

./case.submit







