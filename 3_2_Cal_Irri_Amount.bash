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
output_file="${output_dir}/Yangtze_Irrigation_Dis.nc"

# Step 1: Calculate the demand of each crop = Irrigated harvested area (m2) * Monthly deficit (mm)
StudyAreas=("Yangtze") # "Rhine" "Yangtze" "LaPlata" "Indus"
CropTypes=('mainrice' 'secondrice' 'winterwheat' 'soybean' 'maize') # 'mainrice' 'secondrice' 'springwheat' 'winterwheat' 'soybean' 'maize'

Cal_Monthly_Irri_Demand(){

cdo gencon,lonlat,360,720,1,1 ${process_dir}/lonlat_grid.nc

    for studyarea in "${StudyAreas[@]}"; 
    do  
        original_file=${Irrigation_dir}/${studyarea}_Irrigated_HA.nc
        cdo remapbil,${process_dir}/lonlat_grid.nc $original_file ${Irrigation_dir}/${studyarea}_Irri_HA_regular.nc
        
        irrigated_HA_file=${Irrigation_dir}/${studyarea}_Irri_HA_regular.nc
        irrigation_amount_file=${Irrigation_dir}/${studyarea}_maincrop_IrrAmount.nc
        
        rm -f $process_dir/temp_renamed_*.nc

        for croptype in "${CropTypes[@]}"; 
        do
            deficit_file=${Demand_dir}/${studyarea}_${croptype}_Deficit_monthly.nc
            # Assign variable name
            if [ "$croptype" == "mainrice" ]; then
                var_name="MAINRICE_Irrigated_Area"
            fi
            if [ "$croptype" == "secondrice" ]; then
               var_name="SECONDRICE_Irrigated_Area"
            fi
            if [ "$croptype" == "winterwheat" ]; then
               var_name="WHEA_Irrigated_Area"
            fi
            if [ "$croptype" == "soybean" ]; then
               var_name="SOYB_Irrigated_Area"
            fi
            if [ "$croptype" == "maize" ]; then
               var_name="MAIZ_Irrigated_Area"
            fi            

            cdo selvar,$var_name $irrigated_HA_file $process_dir/temp_${croptype}_Irri_HA.nc
            cdo -O duplicate,$(cdo ntime $deficit_file) $process_dir/temp_${croptype}_Irri_HA.nc $process_dir/temp_${croptype}_Irri_HA_timesteps.nc
            
            start_time=$(cdo showtimestamp $deficit_file | cut -d' ' -f3) # Extract start time
            end_time=$(cdo showtimestamp $deficit_file | cut -d' ' -f5)  # Extract end time
            cdo -O settaxis,$start_time,$end_time,1 $process_dir/temp_${croptype}_Irri_HA_timesteps.nc $process_dir/temp_${croptype}_Irri_HA_timed.nc
            
            cdo -O mul $deficit_file $process_dir/temp_${croptype}_Irri_HA_timed.nc $process_dir/result_${croptype}_multiply.nc

            # Rename the variable for consistency and prepare for merging
            ncrename -v EvaTrans,${croptype}_Demand $process_dir/result_${croptype}_multiply.nc $process_dir/temp_renamed_${croptype}.nc
            ncatted -a units,${croptype}_Demand,m,c,"m3" -a long_name,${croptype}_Demand,m,c,"Monthly irrigation water demand for ${croptype}" $process_dir/temp_renamed_${croptype}.nc

            # Clean up temporary files
            rm $process_dir/temp_${croptype}_Irri_HA_timesteps.nc $process_dir/temp_${croptype}_Irri_HA_timed.nc $process_dir/temp_${croptype}_Irri_HA.nc $process_dir/result_${croptype}_multiply.nc
        
        done
        
        cdo merge $process_dir/temp_renamed_*.nc $process_dir/all_crops_demand.nc
        
        # Calculate the total demand by summing all individual demands
        cdo enssum $process_dir/temp_renamed_*.nc $process_dir/total_demand.nc
        ncrename -v EvaTrans,Total_Demand $process_dir/total_demand.nc
        ncatted -a units,Total_Demand,c,c,"m3" -a long_name,Total_Demand,c,c,"Total monthly irrigation water demand for all crops" $process_dir/total_demand.nc
        
        # Merge the total with the individual demands
        ncks -A $process_dir/total_demand.nc $process_dir/all_crops_demand.nc
        
        mv $process_dir/all_crops_demand.nc $output_file
        
        # Clean up remaining temporary files
        rm -f $process_dir/temp_renamed_*.nc $process_dir/total_demand.nc
        echo "Created combined demand file for $studyarea: $output_file"
    done

}

Cal_Monthly_Irri_Demand

# Step 2: Calculate the proportion of irrigation water goes to each main crop type
Get_Irrigation_Prop(){
    for croptype in "${CropTypes[@]}"; 
    do
        # Create fraction of total demand for each crop
        cdo -O div -selname, ${croptype}_Demand $output_file -selname,Total_Demand $output_file $process_dir/temp_${croptype}_proportion.nc
        
        # Rename the variable to indicate it's a proportion
        ncrename -v ${croptype}_Demand,${croptype}_Proportion $process_dir/temp_${croptype}_proportion.nc
        
        # Add metadata
        ncatted -a units,${croptype}_Proportion,c,c,"fraction" -a long_name,${croptype}_Proportion,c,c,"Proportion of total irrigation demand for ${croptype}" $process_dir/temp_${croptype}_proportion.nc
        
        # Add this variable to the output file
        ncks -A $process_dir/temp_${croptype}_proportion.nc $output_file
        
        # Clean up
        rm $process_dir/temp_${croptype}_proportion.nc
    done
}
Get_Irrigation_Prop