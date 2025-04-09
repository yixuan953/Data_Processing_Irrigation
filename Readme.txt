The scripts of this folder are used to distribute the monthly irrigation amount from Droppers et al. (2020): https://doi.org/10.5194/gmd-13-5029-2020 to main crop types
The distribution methods are as follows:

1 - Calculate how much irrigation water will go to the main crops (maize, rice, wheat, soybean):
    Frac_MainCrop = (Havest area * Irrigated proportion)_MainCrop/(Havest area * Irrigated proportion)_AllCrop
    Here we used the SPAM2005 data (an example of rice) (https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/DHXBJX):
        - Havest area [ha]: SPAM2005V3r2_global_H_TA_RICE_A.tif 
        - Irrigation proportion [-, 0-1]: SPAM2005V3r2_global_H_TI_RICE_I.tif 
    * Pls be noticed that the multiple cropping has been considered as the harvest area from SPAM2005 counted this part
