#!/bin/bash

D=$PWD

#Set name of simulation
CaseName=JG_iteration_1

PreviousBGCaseName=BG_iteration_0

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

# ./xmlchange NTASKS_ATM=16
# ./xmlchange NTASKS_CPL=16
# ./xmlchange NTASKS_GLC=16
# ./xmlchange NTASKS_ICE=16
# ./xmlchange NTASKS_LND=16
# ./xmlchange NTASKS_OCN=16
# ./xmlchange NTASKS_ROF=16
# ./xmlchange NTASKS_WAV=16
# 
# ./xmlchange ROOTPE_ATM=0
# ./xmlchange ROOTPE_CPL=0
# ./xmlchange ROOTPE_GLC=0
# ./xmlchange ROOTPE_ICE=0
# ./xmlchange ROOTPE_LND=0
# ./xmlchange ROOTPE_OCN=0
# ./xmlchange ROOTPE_ROF=0
# ./xmlchange ROOTPE_WAV=0

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
./xmlchange RUN_REFDATE='0002-01-01'

./xmlchange DATM_CPLHIST_CASE="$PreviousBGCaseName"
./xmlchange DATM_MODE='CPLHIST_JG'
./xmlchange DATM_CPLHIST_YR_START=1
./xmlchange DATM_CPLHIST_YR_END=1
./xmlchange DATM_CPLHIST_YR_ALIGN=2

./xmlchange CPL_ALBAV='false'
./xmlchange CPL_EPBAL='off'

#Copy over altered streams (couldn't figure out how to tweak these properly, so just removed all fields
#From them, given these fields now exist in other streams.
#Specifically: the presaero streams were removed (data now read from daily stream)
#Specifically: the topo stream had topo removed (now read from the daily stream)
#cp ../JG_datm_stream_templates/user_datm.streams.txt.presaero.clim_1850 .
#cp ../JG_datm_stream_templates/user_datm.streams.txt.topo.observed .

./case.setup				      
		      
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

echo 'dtlimit = 3.0,3.0,3.0,3.0,3.0' > user_nl_datm
echo "domainfile='/glade/u/cesm-scripts/liwg/Coupled_BG_JG_Spinup/JG_datm_stream_templates/domain_data_JGF_270416.nc'" >> user_nl_datm
echo  "fillalgo = 'nn','nn','nn','nn','nn'" >> user_nl_datm
echo   "fillmask = 'nomask','nomask','nomask','nomask','nomask'" >> user_nl_datm
echo   "mapalgo = 'bilinear','bilinear','bilinear','bilinear','bilinear'" >> user_nl_datm
echo   "mapmask = 'nomask','nomask','nomask','nomask','nomask'" >> user_nl_datm
echo   'streams = "datm.streams.txt.CPLHIST_JG.Solar 2 1 1", "datm.streams.txt.CPLHIST_JG.Winds 2 1 1", "datm.streams.txt.CPLHIST_JG.Precip 2 1 1", "datm.streams.txt.CPLHIST_JG.nonSolarNonPrecip 2 1 1", "datm.streams.txt.CPLHIST_JG.Daily 2 1 1"' >> user_nl_datm
echo   "taxmode = 'cycle','cycle','cycle','cycle','cycle'" >> user_nl_datm
echo   "tintalgo = 'coszen','linear','nearest','linear','linear'" >> user_nl_datm

t=1
let tm1=t-1
JG_t_CaseDir=/glade/u/cesm-scripts/liwg/Coupled_BG_JG_Spinup/JG_iteration_$t
JG_t_RunDir=/glade/scratch/jfyke/JG_iteration_$t/run
JG_t_ArchiveDir=/glade/scratch/jfyke/archive/$PreviousBGCaseName
BG_tm1_ArchiveDir=/glade/scratch/jfyke/archive/$PreviousBGCaseName

#Copy in BHLV downscaling fix and switch to bilinear LND2GLC mapping to override bad conservative downscaling
cp $D/SourceMods/map_lnd2glc_mod.F90 SourceMods/src.drv
./xmlchange LND2GLC_FMAPNAME="cpl/gridmaps/fv0.9x1.25/map_fv0.9x1.25_TO_gland4km_blin.150514.nc"

./xmlchange STOP_OPTION='nyears'
./xmlchange STOP_N=1

./xmlchange HIST_OPTION='nmonths'
./xmlchange HIST_N=1

./xmlchange RESUBMIT=100

RunDir=/glade/scratch/jfyke/$CaseName/run
ln -sf $RunDir RunDir

echo "ice_ic='$RunDir/BG_iteration_0.cice.r.0002-01-01-00000.nc'" > user_nl_cice

ArchiveDir=/glade/scratch/jfyke/archive/$CaseName
ln -sf $ArchiveDir ArchiveDir

./xmlchange JOB_QUEUE='regular'
./xmlchange JOB_WALLCLOCK_TIME='00:30'
./xmlchange PROJECT='P93300601'

./case.build

GLOBIGNORE=*.cam.*:rpointer.atm #Don't copy over any atmospheric restart stuff.
cp $BG_tm1_ArchiveDir/rest/0002-01-01-00000/* $JG_t_RunDir #TODO: update date to 0041 (or whatever full length+1 of BG run is)
GLOBIGNORE=
 
./case.submit





