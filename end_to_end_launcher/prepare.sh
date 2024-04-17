#!/bin/bash
sudo sysctl kernel.numa_balancing=0
#create_die_stacked_mem.sh node_size 0 2048MB # create_die_stacked_mem.sh node_size <node> <size>
#create_die_stacked_mem.sh 2048MB # create_die_stacked_mem.sh <size>
