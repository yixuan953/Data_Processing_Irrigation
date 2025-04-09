#!/bin/bash
#-----------------------------Mail address-----------------------------

#-----------------------------Output files-----------------------------
#SBATCH --output=HPCReport/output_%j.txt
#SBATCH --error=HPCReport/error_output_%j.txt

#-----------------------------Required resources-----------------------
#SBATCH --time=600
#SBATCH --mem=250000

module load cdo
module load nco
module load netcdf

# Input directory
Irrigation_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"
Demand_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/WOFOST_demand"
# Processed directory
process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"
# Output directory
output_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/CaseStudy"

# Step 1: Calculate the demand of each crop (m3) = Irrigated harvested area (m2) * Monthly deficit (mm)
StudyAreas=("Yangtze") # "Rhine" "Yangtze" "LaPlata" "Indus"
CropTypes=('mainrice' 'secondrice' 'winterwheat' 'soybean') # 'mainrice' 'secondrice' 'springwheat' 'winterwheat' 'soybean' 'maize'