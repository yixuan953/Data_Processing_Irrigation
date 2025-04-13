The scripts of this folder are used to distribute the monthly irrigation amount (1980 - 2016) from Droppers et al. (2020): https://doi.org/10.5194/gmd-13-5029-2020 to main crop types
The distribution methods are as follows:

1 - Calculate how much irrigation water (fraction - [0,1], amount [m3]) will go to the main crops (maize, rice, wheat, soybean):
    1-1 Fraction calculation
    Frac_MainCrop = (Havest area * Irrigated proportion)_MainCrop/(Havest area * Irrigated proportion)_AllCrop
    Here we used the SPAM2005 data (an example of rice) (https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/DHXBJX):
        - Havest area [ha]: SPAM2005V3r2_global_H_TA_RICE_A.tif 
        - Irrigation proportion [-, 0-1]: SPAM2005V3r2_global_H_TI_RICE_I.tif 
    * Pls be noticed that the multiple cropping has been considered as the harvest area from SPAM2005 counted this part
    
    1-2 Amount calculation
    Irrigation_Amount_to_MainCrop [m3] = Frac_MainCrop * Monthly irrigation amount from Droppers et al. (2020)
    Here, we:
    Firstly sum up the irrigation amount from all sectors (groundwater, surface water, dam, etc.) # Unit: mm
         [OUT_WI_COMP_SECT,OUT_WI_DAM_SECT,OUT_WI_GW_SECT,OUT_WI_NREN_SECT,OUT_WI_REM_SECT,OUT_WI_SURF_SECT]
         * Pls be noticed that here the mm is calculated using the total irrigation amount/pixel area
    Then calculate the monthly irrigation amount goes to main crops = Frac_MainCrop * Monthly irrigation (mm) * pixel_area (m2)/1000 (unit transform)

2 - Calculate how to distribut the irrigation water amount for all maincrops to individual crop types
    2-1: Calculate the daily "deficit" of each crop, and aggregate the "deficit" to monthly scale
    Here the "deficit" = Evapotranspiration (withour water limitation) - Precipitation
        1) Evapotranspiration is simulated by wofost for each crop type, driven meteo data is from WFDE5
        2) Precipitation is the WFDE5 data
    The code for deficit calculation can be found in <Irri_Demand> folder from https://github.com/yixuan953/Results_Analysis 
    2-2: Proportion_Irri_Dis of each crop type = (Monthly_Deficit * Irrigated_harvest_area)_croptype_1 / Sum(Monthly_Deficit * Irrigated_harvest_area)_all_main_crops
        
3 - Calculate the monthly irrigation amount (m3) and irrigation rate (mm - for irrgation area) for each crop type
    Here:
    3-1: Irrigation amount given to each individual crop type = Total irrigation amount for main crops (m3) * Proportion (calculated in step2)
    3-2: Irrigation rate (mm) = Total amount given to each individual crop type/Irrigated harvest area