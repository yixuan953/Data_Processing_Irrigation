#!/bin/bash
#-----------------------------Mail address-----------------------------

#-----------------------------Output files-----------------------------
#SBATCH --output=HPCReport/output_%j.txt
#SBATCH --error=HPCReport/error_output_%j.txt

#-----------------------------Required resources-----------------------
#SBATCH --time=600
#SBATCH --mem=250000

#--------------------Environment, Operations and Job steps-------------
module load python/3.12.0
# pip install dbfread

# Step 1: Calculate how much irrigation water would go to main crop
# Transform the data from tiff format to nc (SPAM2005)
python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/1_1_Trans_tiff_nc.py