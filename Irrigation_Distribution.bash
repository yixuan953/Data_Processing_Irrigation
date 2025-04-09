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

# Step 1: Calculate how much irrigation water (fraction) would go to main crop
# 1-1: Transform the data from tiff format to nc (SPAM2005)
# python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/1_1_Trans_tiff_nc.py
# 1-2: Calculate the fraction of main crop 
# python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/1_2_Cal_Frac.py

# Step 2: Calculate the amount total irrigation water goes to the main crops
IRRIG_FILE="/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/Irrigation/VIC_Bram/irrigationWithdrawal_monthly_1979_2016.nc"
FRAC_FILE="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/MainCrop_Fraction_05d.nc"
process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation"

# 2-1: Sum up the total irrigation amount from all sectors (e.g., groundwater, reservoir, etc.)
Sum_Irri(){

}