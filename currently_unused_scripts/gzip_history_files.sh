#!/bin/bash

#BSUB -P P93300301
#BSUB -W 00:30               
#BSUB -n 128                  
#BSUB -J gzip_history        
#BSUB -o gzip_history.%J.out 
#BSUB -e gzip_history.%J.err 
#BSUB -q regular         

module purge
module load parallel

D=/glade/scratch/jfyke/JG_iteration_3/run

ls $D/*.nc | parallel gzip -f

