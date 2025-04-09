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

# This code is used to get the irrigated area of main crops for the study area
# Input data
crop_mask_dir="/lustre/nobackup/WUR/ESG/zhou111/Model_Results/1_Yp_WOFOST"
demand_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/WOFOST_demand"
irrigated_ha="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/MainCrop_Fraction_05d.nc"
irrigation_amount="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/maincrop_irrigation.nc"

# Processed direction
process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"

# Output data
output_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/CaseStudy"

StudyAreas=("Rhine" "Yangtze" "LaPlata" "Indus") # "Rhine" "Yangtze" "LaPlata" "Indus"

# Step 1: Cut the irrigated amount and irrigated harvest area for our case study areas (spatial range)
Cut_HA(){
    for StudyArea in "${StudyAreas[@]}"; 
    do
        crop_mask="${crop_mask_dir}/${StudyArea}/${StudyArea}_maize_Yp_mask.nc" 
        # The spatial range are the same for all crops. Here I use maize to cut irrigated HA as all of four study areas plant maize
        lat_min=$(ncdump -v lat $crop_mask | grep -oP "[-]?[0-9]+\.[0-9]+(?=,|\s)" | sort -n | head -n 1)
        lat_max=$(ncdump -v lat $crop_mask | grep -oP "[-]?[0-9]+\.[0-9]+(?=,|\s)" | sort -n | tail -n 1)
        lon_min=$(ncdump -v lon $crop_mask | grep -oP "[-]?[0-9]+\.[0-9]+(?=,|\s)" | sort -n | head -n 1)
        lon_max=$(ncdump -v lon $crop_mask | grep -oP "[-]?[0-9]+\.[0-9]+(?=,|\s)" | sort -n | tail -n 1)

        echo "Bounding box: lon=($lon_min, $lon_max), lat=($lat_min, $lat_max)"

        # Step 2: Cut using the bounding box
        # Here I am not using cdo as the irrigated_ha .nc file is identified as generic (probably because it was transformed from .tif file)
        # cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max $irrigated_ha ${process_dir}/${StudyArea}_Irrigated_HA.nc
        ncks -d lon,$lon_min,$lon_max -d lat,$lat_min,$lat_max $irrigated_ha ${process_dir}/${StudyArea}_Irrigated_HA.nc
        cdo sellonlatbox,$lon_min,$lon_max,$lat_min,$lat_max $irrigation_amount ${process_dir}/${StudyArea}_maincrop_IrrAmount.nc
    done      
}

# Cut_HA

# Step 2: Divide irrigated area of rice into two if second rice is planted
irrigated_file="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy/Yangtze_Irrigated_HA.nc"
secondrice_mask="/lustre/nobackup/WUR/ESG/zhou111/Model_Results/1_Yp_WOFOST/Yangtze/Yangtze_secondrice_Yp_mask.nc"
temp_file="${process_dir}/temp_rice_calc"

Divede_HA(){ 

    cdo -O ifthen -selname,Yp $secondrice_mask -selname,RICE_Irrigated_Area $irrigated_file ${temp_file}_secondrice_mask.nc

    # Calculate SECONDRICE_Irrigated_Area (half of RICE_Irrigated_Area where masked)
    cdo -O mulc,0.5 ${temp_file}_secondrice_mask.nc ${temp_file}_secondrice_area.nc

    # Calculate MAINRICE_Irrigated_Area (RICE_Irrigated_Area - SECONDRICE_Irrigated_Area)
    cdo -O setmisstoc,0 ${temp_file}_secondrice_area.nc ${temp_file}_secondrice_area_nomissing.nc
    cdo -O sub -selname,RICE_Irrigated_Area $irrigated_file ${temp_file}_secondrice_area_nomissing.nc ${temp_file}_mainrice_area.nc

    # Rename variables
    ncrename -v RICE_Irrigated_Area,SECONDRICE_Irrigated_Area ${temp_file}_secondrice_area.nc
    ncrename -v RICE_Irrigated_Area,MAINRICE_Irrigated_Area ${temp_file}_mainrice_area.nc

    ncatted -a units,SECONDRICE_Irrigated_Area,c,c,"ha" -a long_name,SECONDRICE_Irrigated_Area,c,c,"Irrigated area for second RICE" ${temp_file}_secondrice_area.nc
    ncatted -a units,MAINRICE_Irrigated_Area,c,c,"ha" -a long_name,MAINRICE_Irrigated_Area,c,c,"Irrigated area for main RICE" ${temp_file}_mainrice_area.nc

    # Merge the new variables into the original file
    ncks -A ${temp_file}_secondrice_area.nc $irrigated_file
    ncks -A ${temp_file}_mainrice_area.nc $irrigated_file

    # Clean up temporary files
    rm ${temp_file}*

    echo "Processing complete. New variables added to $irrigated_file"
}
Divede_HA