#!/bin/bash

D=BG_iteration_2/RunDir

gzip -v $D/*cice.h* &
gzip -v $D/*clm2.h* &
gzip -v $D/*cpl.hi* &
gzip -v $D/*mosart.h0* &
gzip -v $D/*pop.h.00* &
gzip -v $D/*pop.h.nday1* &
gzip -v $D/*cam.h0* &

wait


