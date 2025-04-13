#!/bin/bash
#-----------------------------Mail address-----------------------------

#-----------------------------Output files-----------------------------
#SBATCH --output=HPCReport/output_%j.txt
#SBATCH --error=HPCReport/error_output_%j.txt

#-----------------------------Required resources-----------------------
#SBATCH --time=600
#SBATCH --mem=250000

# This code is used to calculate: 
# 4-1: Irrigation amount given to each individual crop type = Total irrigation amount for main crops (m3) * Proportion (calculated in step3)
# 4-2: Irrigation rate (mm) = Total amount given to each individual crop type/Irrigated harvest area

module load cdo
module load nco

input_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"
process_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/CaseStudy"
output_dir="/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation/CaseStudy"

StudyAreas=("Yangtze") # "Rhine" "Yangtze" "LaPlata" "Indus"
CropTypes=('mainrice' 'secondrice' 'winterwheat' 'soybean' 'maize') # 'mainrice' 'secondrice' 'springwheat' 'winterwheat' 'soybean' 'maize'


GetIrriAmount(){
    for studyarea in "${StudyAreas[@]}"; 
    do 

    # Read the irrigation amount and remove the wu_class variable
    irrigation_amount_original=${input_dir}/${studyarea}_maincrop_IrrAmount.nc
    ncks -d wu_class,0 $irrigation_amount_original $process_dir/temp_${studyarea}_maincrop_IrrAmount_MoveWUC.nc
    ncwa -a wu_class $process_dir/temp_${studyarea}_maincrop_IrrAmount_MoveWUC.nc $process_dir/${studyarea}_maincrop_IrrAmount_clean.nc
    
    Irri_Amount_File=$process_dir/${studyarea}_maincrop_IrrAmount_clean.nc
    
    # Select the irrigation d
    # cdo selvar,MAIN_CROP_IRRIGATION $Irri_Amount_File $process_dir/temp_${studyarea}_sel_Irri_amount.nc

    # Read the irrigation distribution proportion for individual main crops
    Irri_Pro_File=$process_dir/${studyarea}_all_crops_demand.nc

        for croptype in "${CropTypes[@]}";
        do 
            cdo selvar,${croptype}_Proportion $Irri_Pro_File $process_dir/temp_${studyarea}_${croptype}_Irri_Pro.nc
            cdo -O mul $Irri_Amount_File $process_dir/temp_${studyarea}_${croptype}_Irri_Pro.nc $process_dir/temp_${studyarea}_${croptype}_Monthly_IrrAmount.nc
            ncrename -v MAIN_CROP_IRRIGATION,Irrigation_Amount $process_dir/temp_${studyarea}_${croptype}_Monthly_IrrAmount.nc $process_dir/Renamed_${studyarea}_${croptype}_Monthly_IrrAmount.nc
            ncatted -a units,Irrigation_Amount,m,c,"m3" -a long_name,Irrigation_Amount,m,c,"Monthly irrigation amount for ${croptype}" $process_dir/Renamed_${studyarea}_${croptype}_Monthly_IrrAmount.nc
            mv $process_dir/Renamed_${studyarea}_${croptype}_Monthly_IrrAmount.nc $output_dir/${studyarea}_${croptype}_monthly_Irri_Amount.nc    
            echo "Irrigation amount for $croptype for $studyarea is calculated and saved"
        done

    done

}

GetIrriAmount

GetIrriRate(){
    for studyarea in "${StudyAreas[@]}"; 
    do 
    HA_file=$input_dir/${studyarea}_Irrigated_HA.nc

        for croptype in "${CropTypes[@]}";
        do 
            # -----  Extract the correcponding irrigated harvest area --------
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
            cdo selvar,$var_name $HA_file $process_dir/${studyarea}_${croptype}_Irrigated_HA.nc
            # ---------------------------------------------------------

            # ----------- Calculate the irrigation rate [mm] ----------
            # Irrigation rate [mm] = (Irrigation amount [m3] / Irrigated harvest area [ha]) * 10
            
            Irri_Amount=$output_dir/${studyarea}_${croptype}_monthly_Irri_Amount.nc
            cdo -O duplicate,$(cdo ntime $Irri_Amount) $process_dir/${studyarea}_${croptype}_Irrigated_HA.nc $process_dir/temp_${studyarea}_${croptype}_Irrigated_HA_bc.nc
            cdo mulc,10 -div $Irri_Amount -setgrid,$Irri_Amount $process_dir/temp_${studyarea}_${croptype}_Irrigated_HA_bc.nc $process_dir/temp_${studyarea}_${croptype}_Irrigated_Rate.nc
            cdo -setmissval,0 $process_dir/temp_${studyarea}_${croptype}_Irrigated_Rate.nc $process_dir/temp_${studyarea}_${croptype}_IrriRate_clean.nc
            # ---------------------------------------------------------

            # Rename the variable and save the result
            ncrename -v Irrigation_Amount,Irrigation_Rate $process_dir/temp_${studyarea}_${croptype}_IrriRate_clean.nc $process_dir/Renamed_${studyarea}_${croptype}_IrriRate.nc
            ncatted -a units,Irrigation_Rate,m,c,"mm" -a long_name,Irrigation_Rate,m,c,"Monthly irrigation rate for ${croptype}" $process_dir/Renamed_${studyarea}_${croptype}_IrriRate.nc
            mv $process_dir/Renamed_${studyarea}_${croptype}_IrriRate.nc $output_dir/${studyarea}_${croptype}_monthly_Irri_Rate.nc    
            echo "Irrigation rate for $croptype for $studyarea is calculated and saved"           
        
        done

    done
}

GetIrriRate