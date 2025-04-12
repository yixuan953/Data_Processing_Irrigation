#!/bin/bash
#-----------------------------Mail address-----------------------------

#-----------------------------Output files-----------------------------
#SBATCH --output=HPCReport/output_%j.txt
#SBATCH --error=HPCReport/error_output_%j.txt

#-----------------------------Required resources-----------------------
#SBATCH --time=600
#SBATCH --mem=250000

# This code is used to: 
# 1. calculate the demand of each crop = Irrigated harvested area (m2) * Monthly deficit (mm)

module load cdo
module load nco
module load python/3.12.0

# Input directory
Irrigation_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"
Demand_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/WOFOST_demand"
# Processed directory
process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"
# Output directory
output_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/CaseStudy"
output_file="${output_dir}/Yangtze_Irrigation_Dis.nc"

StudyAreas=("Yangtze") # "Rhine" "Yangtze" "LaPlata" "Indus"
CropTypes=('mainrice' 'secondrice' 'winterwheat' 'soybean' 'maize') # 'mainrice' 'secondrice' 'springwheat' 'winterwheat' 'soybean' 'maize'

# Part 1: Get the demand of each crop, and save them in seperate .nc files
Cal_Monthly_Irri_Demand(){
    
    for studyarea in "${StudyAreas[@]}"; 
    do  
       
        irrigation_amount_file=${Irrigation_dir}/${studyarea}_maincrop_IrrAmount.nc
        reference_file=$irrigation_amount_file # Use the time dimension of the irrigation file (VIC-WUR) as the reference file
        
        irrigated_HA_file=${Irrigation_dir}/${studyarea}_Irrigated_HA.nc
        
        for croptype in "${CropTypes[@]}"; 
        do
            deficit_file=${Demand_dir}/${studyarea}_${croptype}_Deficit_monthly.nc

            # Expand the temporal range of the irrigated_HA file
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

            # Expand the temporal range of the irrigated_HA file
            cdo -O duplicate,$(cdo ntime $deficit_file) $process_dir/temp_${croptype}_Irri_HA.nc $process_dir/temp_${croptype}_Irri_HA_timesteps.nc
            cdo showtimestamp $deficit_file > $process_dir/${croptype}_timestamps.txt
            sed 's/T/ /g' $process_dir/${croptype}_timestamps.txt > $process_dir/cleaned_${croptype}_timestamps.txt
            sed 's/^[ \t]*//;s/[ \t]*$//' $process_dir/cleaned_${croptype}_timestamps.txt > $process_dir/cleaned_${croptype}_timestamps_cleaned.txt
            sed -i 's/[[:space:]]*$//' $process_dir/cleaned_${croptype}_timestamps_cleaned.txt
            # Convert multiple spaces to newlines
            cat $process_dir/cleaned_${croptype}_timestamps_cleaned.txt | tr -s ' ' '\n' | grep -v '^$' > $process_dir/cleaned_${croptype}_timestamps_seperated.txt
            cat $process_dir/cleaned_${croptype}_timestamps_seperated.txt | cdo -setdate,- $process_dir/temp_${croptype}_Irri_HA_timesteps.nc $process_dir/temp_${croptype}_Irri_HA_timed.nc

            # Expand the spatial range of the deficit file 
            cdo griddes $process_dir/temp_${croptype}_Irri_HA_timed.nc > $process_dir/target_grid.txt
            cdo remapnn,$process_dir/target_grid.txt $deficit_file $process_dir/temp_${croptype}_deficit_expanded.nc # The time dimension only contains the growing month

            # Get the demand of each crop        
            cdo -O mul $process_dir/temp_${croptype}_deficit_expanded.nc $process_dir/temp_${croptype}_Irri_HA_timed.nc $process_dir/result_${croptype}_multiply.nc

            # Rename the variable for consistency and prepare for merging
            ncrename -v EvaTrans,${croptype}_Demand $process_dir/result_${croptype}_multiply.nc $process_dir/temp_renamed_${croptype}.nc
            ncatted -a units,${croptype}_Demand,m,c,"m3" -a long_name,${croptype}_Demand,m,c,"Monthly irrigation water demand for ${croptype}" $process_dir/temp_renamed_${croptype}.nc
            done
    done
}

# Cal_Monthly_Irri_Demand

# Step 2: Align the time dimesion of the irrigation demands of each crop, and merge the total demand 
Merge_Demand(){
    export HDF5_DISABLE_VERSION_CHECK=1    
    for studyarea in "${StudyAreas[@]}"; 
    do  
        irrigation_amount_file=${Irrigation_dir}/${studyarea}_maincrop_IrrAmount.nc

        # Add the missing month as the crops are not planted in every month of each year
        python /lustre/nobackup/WUR/ESG/zhou111/Code/Data_Processing/Irrigation/3_2_2_Fill_missing_month.py

        # Replace the missing value of individual crop demand with 0
        for croptype in "${CropTypes[@]}"; 
        do
            file=$process_dir/temp_aligned_${croptype}.nc
            tmpfile=$process_dir/temp_aligned_tmp_${croptype}.nc
            outfile=$process_dir/temp_aligned_filled_${croptype}.nc

            cdo -L -setmissval,-9999 "$file" "$tmpfile" # Step 1: Set the missing value to a known one (-9999)
            cdo -expr,"${croptype}_Demand=(${croptype}_Demand==-9999) ? 0 : ${croptype}_Demand" "$tmpfile" "$outfile"

            rm "$tmpfile"
            if [ "$croptype" = "${CropTypes[0]}" ]; then
                cp "$outfile" $process_dir/all_crops_demand.nc
            else
                # For subsequent crops, append to the file
                ncks -A -v ${croptype}_Demand "$outfile" $process_dir/all_crops_demand.nc
            fi
        done

        # Sum up the total demand 
        cdo enssum $process_dir/temp_aligned_filled*.nc $process_dir/total_demand.nc
        ncrename -v ${CropTypes[0]}_Demand,Total_Demand $process_dir/total_demand.nc
        ncatted -a units,Total_Demand,c,c,"m3" -a long_name,Total_Demand,c,c,"Total monthly irrigation water demand for all crops" $process_dir/total_demand.nc
        cdo -L -expr,'Total_Demand=(Total_Demand==-9999) ? 1.0/0.0 : Total_Demand' \
            -copy $process_dir/total_demand.nc \
            $process_dir/total_demand_nan.nc
        # Merge the total with the individual demands
        ncks -A -v Total_Demand $process_dir/total_demand_nan.nc $process_dir/all_crops_demand.nc
        
        echo "Created combined demand file for $studyarea: $process_dir/all_crops_demand.nc"

    done
}
# Merge_Demand


# Step 3: Calculate the proportion of irrigation water goes to each main crop type
Get_Irrigation_Prop(){
    for croptype in "${CropTypes[@]}"; 
    do
        # Create fraction of total demand for each crop
        cdo -O div -selname,${croptype}_Demand $process_dir/all_crops_demand.nc -selname,Total_Demand $process_dir/all_crops_demand.nc $process_dir/temp_${croptype}_proportion.nc
        
        # Rename the variable to indicate it's a proportion
        ncrename -v ${croptype}_Demand,${croptype}_Proportion $process_dir/temp_${croptype}_proportion.nc
        
        # Add metadata
        ncatted -a units,${croptype}_Proportion,c,c,"fraction" -a long_name,${croptype}_Proportion,c,c,"Proportion of total irrigation demand for ${croptype}" $process_dir/temp_${croptype}_proportion.nc
        
        # Add this variable to the output file
        ncks -A $process_dir/temp_${croptype}_proportion.nc $process_dir/all_crops_demand.nc
        
    done
}
# Get_Irrigation_Prop

# Clean up
CleanUp(){
    rm $process_dir/temp_${croptype}_proportion.nc
}
# CleanUp