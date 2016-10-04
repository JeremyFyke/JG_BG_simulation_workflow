#/bin/bash

LindsayModDir=/glade/p/cesmdata/cseg/runs/cesm1_3/b.e13.B20TRC5CLM45BGC-BDRD.f09_g16.001/SourceMods

#for SMDir in src.share src.drv; do
#  for f in `ls $LindsayModDir/$SMDir/*.F90`; do
#    echo ''
#    xxdiff $f default_code/$(basename $f) &
#    #grep  'SVN $URL' $f
#  done
#done

xxdiff ../SourceMods/cesm_comp_mod.F90    default_code/ccsm_comp_mod.F90 $LindsayModDir/src.drv/ccsm_comp_mod.F90 #DONE
#xxdiff ../SourceMods/seq_hist_mod.F90     default_code/seq_hist_mod.F90 $LindsayModDir/src.drv/seq_hist_mod.F90 #NOT DONE - LOOKS LIKE FILE IO PERFORMANCE STUFF
#xxdiff ../SourceMods/seq_infodata_mod.F90 default_code/seq_infodata_mod.F90 $LindsayModDir/src.share/seq_infodata_mod.F90 #DONE
#xxdiff ../SourceMods/seq_io_mod.F90       default_code/seq_io_mod.F90 $LindsayModDir/src.drv/seq_io_mod.F90  #NOT DONE - LOOKS LIKE FILE IO PERFORMANCE STUFF

#xxdiff /glade/u/home/jfyke/work/CESM_model_versions/cesm1_3_beta07/cime/driver_cpl/bld/namelist_files/namelist_defaults_drv.xml $LindsayModDir/src.drv/namelist_defaults_drv.xml #DONE

#xxdiff /glade/u/home/jfyke/work/CESM_model_versions/cesm1_3_beta07/models/drv/bld/namelist_files/namelist_definition_drv.xml $LindsayModDir/src.drv/namelist_definition_drv.xml #DONE
