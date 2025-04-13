# This code is used to sum up the irrigation water coming from different sectors
import xarray as xr
import numpy as np

# Load dataset
ds = xr.open_dataset("/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/Irrigation/VIC_Bram/irrigationWithdrawal_monthly_1979_2016.nc")
# Select variables
selected_vars = ['OUT_WI_COMP_SECT', 'OUT_WI_DAM_SECT', 'OUT_WI_GW_SECT', 
                 'OUT_WI_NREN_SECT', 'OUT_WI_REM_SECT', 'OUT_WI_SURF_SECT']

stacked = xr.concat([ds[var] for var in selected_vars], dim='ens')
fill_value = 9.96921e+36
stacked = stacked.where(stacked != fill_value)

summed = stacked.sum(dim='ens', skipna=True)

# Ensure all-NaN locations stay NaN (not 0)
summed = summed.where(stacked.count(dim='ens') >= 0)

summed.name = "TOTAL_IRRIGATION"
ds_out = summed.to_dataset()
summed.to_netcdf("/lustre/nobackup/WUR/ESG/zhou111/Data/Processed/Irrigation/total_irrigation.nc")