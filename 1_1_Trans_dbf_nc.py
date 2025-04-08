# This code is used to transform SPAM2005 harvest area from .dbf format to .nc format
import pandas as pd
import xarray as xr
import numpy as np
import os
import glob
from dbfread import DBF

# Get the coordinates from the cell5m
xytable = DBF("/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/HarvestArea/spam2005v3r2_global_harv_area/cell5m_allockey_xy.dbf", encoding='latin1')  # or try cp1252
xy_df = pd.DataFrame(iter(xytable))
print("Column names in DBF file:", xy_df.columns)

xy_df = pd.DataFrame(iter(xytable))[['X', 'Y', 'ALLOC_KEY']]
xy_df = xy_df.rename(columns={'X': 'lon', 'Y': 'lat'})
lat_vals = np.sort(xy_df['lat'].unique())
lon_vals = np.sort(xy_df['lon'].unique())

folder_path = '/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/HarvestArea/spam2005v3r2_global_harv_area'
dbf_files = glob.glob(os.path.join(folder_path, '*.DBF'))
encodings_to_try = ['latin1', 'cp1252', 'cp850', 'cp437', 'windows-1250', 'iso-8859-2']

for dbf_file_names in dbf_files:
    if 'allockey_xy' in dbf_file_names.lower():
        continue  # Skip the XY table
    print(f"Processing .DBF file: {dbf_file_names}")

    # Try different encodings one at a time:
    for enc in encodings_to_try:
        try:
            print(f"Trying encoding: {enc}")
            table = DBF(dbf_file_names, encoding=enc)
            df = pd.DataFrame(iter(table))
            print(df.head())
            break  # Success
        except UnicodeDecodeError as e:
            print(f"Failed with {enc}: {e}")
    
    if 'alloc_key' not in df.columns:
        print(f"Skipping {dbf_file_names} — no alloc_key found.")
        continue

    # Merge with XY to add lat/lon
    merged = pd.merge(df, xy_df, on='alloc_key', how='inner')

    if 'VALUE' not in merged.columns:
        # Try to infer data column
        data_col = [col for col in merged.columns if col.lower() not in ['alloc_key', 'lat', 'lon']]
        if len(data_col) != 1:
            print(f"Cannot determine value column in {dbf_file_names}, found: {data_col}")
            continue
        value_col = data_col[0]
    else:
        value_col = 'VALUE'

    # Pivot to grid
    grid = merged.pivot(index='lat', columns='lon', values=value_col).sort_index(ascending=False)

    # Create xarray DataArray
    da = xr.DataArray(
        grid.values,
        coords={'lat': grid.index.values, 'lon': grid.columns.values},
        dims=['lat', 'lon'],
        name=value_col.lower(),
        attrs={"source": os.path.basename(dbf_file_names)}
    )

    # Save to NetCDF
    nc_file_name = os.path.basename(dbf_file_names).replace('.DBF', '.nc').replace('.dbf', '.nc')
    da.to_netcdf(os.path.join(folder_path, nc_file_name))
    print(f"Saved: {nc_file_name}")