import pandas as pd
import xarray as xr
import numpy as np

# Step 1: Read the CSV files
file1 = "/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/HarvestArea/spam2005v3r2_global_harv_area/cell5m_allockey_xy.csv"  # Replace with the actual file path
file2 = "/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/HarvestArea/spam2005v3r2_global_harv_area/spam2005V3r2_global_H_TA.csv"  # Replace with the actual file path

# Try skipping problematic lines and handling quotes
df1 = pd.read_csv(file1, on_bad_lines='skip', quotechar='"', engine='python', encoding='utf-8', errors='replace')
df2 = pd.read_csv(file2, on_bad_lines='skip', quotechar='"', engine='python', encoding='utf-8', errors='replace')




# Step 2: Merge the two dataframes (assuming they share a common column like 'alloc_key' or 'hc_seq5m')
df = pd.merge(df1, df2, on='alloc_key', how='inner')  # Adjust the merge column as needed

# Step 3: Filter columns with numerical values
numeric_columns = df.select_dtypes(include=np.number).columns
df_numeric = df[numeric_columns]

# Step 4: Create coordinates (for example, 'alloc_key' could be the index)
# You can adjust this based on how you want to structure your coordinates.
# Assuming 'alloc_key' or 'hc_seq5m' are unique identifiers for each grid cell or observation.

coords = {'alloc_key': df['alloc_key'].values}  # Or you can use other coordinate dimensions

# Step 5: Create an xarray.Dataset
dataset = xr.Dataset.from_dataframe(df_numeric)

# Step 6: Save to .nc file
output_nc_file = "SPAM2005_TA.nc"  # Specify the output file path
dataset.to_netcdf(output_nc_file)

print(f"NetCDF file saved to {output_nc_file}")
