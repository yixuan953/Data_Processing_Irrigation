#!/bin/bash
#-----------------------------Mail address-----------------------------

#-----------------------------Required resources-----------------------
#SBATCH --time=60
#SBATCH --mem=25000

# This code is used to: clean up the data that were created in the irrigation processing

process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"

# Clean up
CleanUp(){
    rm $process_dir/cleaned*.txt
    rm $process_dir/temp*.nc
    rm $process_dir/result*.nc
    rm $process_dir/total*.nc
    rm $process_dir/maize*.nc
    rm $process_dir/winterwheat*.nc
    rm $process_dir/springwheat*.nc
    rm $process_dir/mainrice*.nc
    rm $process_dir/secondrice*.nc
    rm $process_dir/soybean*.nc
    
}

CleanUp