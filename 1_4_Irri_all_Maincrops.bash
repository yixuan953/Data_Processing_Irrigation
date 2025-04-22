#!/bin/bash
#-----------------------------Mail address-----------------------------

#-----------------------------Output files-----------------------------
#SBATCH --output=HPCReport/output_%j.txt
#SBATCH --error=HPCReport/error_output_%j.txt

#-----------------------------Required resources-----------------------
#SBATCH --time=600
#SBATCH --mem=250000

#--------------------Environment, Operations and Job steps-------------
# module load python/3.12.0
module load cdo
IRRIG_FILE="/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/Irrigation/VIC_Bram/irrigationWithdrawal_monthly_1979_2016.nc"
FRAC_FILE="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/MainCrop_Fraction_05d.nc"
process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation"
output_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation"

# This code is to: 
# 1) Calculate how much irrigation water (fraction) would go to main crop
# 2) Calculate how much irrigation water (amount, m3) would go to main crop

# 1-1: Transform the data from tiff format to nc (SPAM2005)
# python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/1_1_Trans_tiff_nc.py

# 1-2: Calculate the fraction of main crop 
# python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/1_2_Cal_Frac.py

# 1-3: Sum up the total irrigation amount from all sectors (e.g., groundwater, reservoir, etc.) # Unit: [mm]
# python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/1_3_Sum_Irri_Sec.py

# 1-4: Match the grid of two .nc files if needed(total irrigation amount & fraction goes to main crop)
Grid_Match(){
    echo "Checking grid definitions..."
    IRRIG_GRID=$(cdo griddes $process_dir/total_irrigation.nc)
    FRAC_GRID=$(cdo griddes $FRAC_FILE)

    # Compare grid information (number of cells should be sufficient)
    IRRIG_GRID_SIZE=$(echo "$IRRIG_GRID" | grep "gridsize" | awk '{print $3}')
    FRAC_GRID_SIZE=$(echo "$FRAC_GRID" | grep "gridsize" | awk '{print $3}')

    if [ "$IRRIG_GRID_SIZE" != "$FRAC_GRID_SIZE" ]; then
        echo "Grids don't match. Regridding irrigation data to match fraction data..."
        # Create a weights file for conservative remapping
        cdo gencon,${FRAC_FILE} $process_dir/total_irrigation.nc $process_dir/weights.nc
        # Apply the weights for remapping
        cdo -O remap,${FRAC_FILE},$process_dir/weights.nc $process_dir/total_irrigation.nc $process_dir/total_irrigation_regridded.nc
        TOTAL_IRRIG_FILE="$process_dir/total_irrigation_regridded.nc"
    else
        echo "Grids match. No regridding needed."
        TOTAL_IRRIG_FILE="$process_dir/total_irrigation.nc"
    fi
}

# Grid_Match

# 1_4 Calculate the amount total irrigation water goes to the main crops [m3]
# Here the irrigation amount = irrigation rate [mm] * total irrigated area [ha]
Get_Irri_MainCrop(){
    echo "Calculating irrigation for main crops..."
    # Fraction goes to main crops [-]
    cdo selvar,Frac_MainCrop $output_dir/MainCrop_Fraction_05d.nc $process_dir/frac_maincrop.nc # Unit [-]
    cdo -setrtoc,0.0,0.0,9.96921e+36 -setmissval,9.96921e+36 $process_dir/frac_maincrop.nc $process_dir/frac_MainCrop_nan.nc

    # Irrigation rate [mm]
    cdo selvar,TOTAL_IRRIGATION $process_dir/total_irrigation.nc $process_dir/total_irrigation_only.nc
    cdo invertlat $process_dir/total_irrigation_only.nc $process_dir/total_irrigation_only_latinvert.nc

    # Irrigation area [ha]
    cdo selvar,All_Crop_Irrigated_Area $output_dir/MainCrop_Fraction_05d.nc $process_dir/irrigated_area_all_05d.nc

    # Merge the required variables
    cdo merge $process_dir/total_irrigation_only_latinvert.nc $process_dir/frac_MainCrop_nan.nc $process_dir/irrigated_area_all_05d.nc $process_dir/merged_input.nc

    # Calculate the total irrigation amount goes to the main crops
    cdo -L -expr,'MAIN_CROP_IRRIGATION=TOTAL_IRRIGATION*Frac_MainCrop*All_Crop_Irrigated_Area*10' \
        -merge $process_dir/merged_input.nc \
        $output_dir/maincrop_irrigation.nc

}

Get_Irri_MainCrop