The scripts of this folder are used to distribute the monthly irrigation amount (1980 - 2016) from Droppers et al. (2020): https://doi.org/10.5194/gmd-13-5029-2020 to main crop types
The distribution methods are as follows:

1 - Calculate how much irrigation water (fraction - [0,1]) will go to the main crops (maize, rice, wheat, soybean):
    Frac_MainCrop = (Havest area * Irrigated proportion)_MainCrop/(Havest area * Irrigated proportion)_AllCrop
    Here we used the SPAM2005 data (an example of rice) (https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/DHXBJX):
        - Havest area [ha]: SPAM2005V3r2_global_H_TA_RICE_A.tif 
        - Irrigation proportion [-, 0-1]: SPAM2005V3r2_global_H_TI_RICE_I.tif 
    * Pls be noticed that the multiple cropping has been considered as the harvest area from SPAM2005 counted this part

2 - Calculate how much irrigation water amount will be distributed to the main crops
    Irrigation_Amount_to_MainCrop = Frac_MainCrop * Monthly irrigation amount from Bram
    Here, we:
    2-1: Sum up the irrigation amount from all sectors (groundwater, surface water, dam, etc.) # Unit: mm
         [OUT_WI_COMP_SECT,OUT_WI_DAM_SECT,OUT_WI_GW_SECT,OUT_WI_NREN_SECT,OUT_WI_REM_SECT,OUT_WI_SURF_SECT]
         * Pls be noticed that here the mm is calculated using the total irrigation amount/pixel area
    2-2: Check if the grids match or not
    2-3: Calculate the monthly irrigation amount goes to main crop

3 - Calculate the 