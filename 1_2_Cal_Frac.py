# This code is used to calculate how much irrigation water (fraction) will go to main crops

import os
import numpy as np
import xarray as xr

# Define paths
input_path = "/lustre/nobackup/WUR/ESG/zhou111/Data/Havest_Area"
output_path = "/lustre/nobackup/WUR/ESG/zhou111/Data/Irrigation"

# Define main crops
main_crops = ["RICE", "WHEA", "MAIZ", "SOYB"]

# Get all the crop files
all_nc_files = [f for f in os.listdir(input_path) if f.endswith("_HA_Irri_05d.nc")]
all_crops = [f.split("_")[0] for f in all_nc_files]

print(f"Found {len(all_nc_files)} crop netCDF files")

# Check if main crops exist in the data
for crop in main_crops:
    if f"{crop}_HA_Irri_05d.nc" not in all_nc_files:
        print(f"Warning: Main crop {crop} not found in dataset")

# Function to calculate irrigated area (Harvest Area * Irrigated Proportion)
def calculate_irrigated_area(file_path):
    """Calculate irrigated area from a crop netCDF file"""
    try:
        ds = xr.open_dataset(file_path)
        
        # Check if required variables exist
        if "Harvest_Area" not in ds or "Irrigated_Proportion" not in ds:
            print(f"Error: Required variables missing in {file_path}")
            return None
        
        # Calculate irrigated area
        irrigated_area = ds["Harvest_Area"] * ds["Irrigated_Proportion"]
        
        # Replace NaN with 0 for proper summation
        irrigated_area = irrigated_area.fillna(0)
        
        # Get lat/lon coordinates for later
        if "lat" in ds.dims and "lon" in ds.dims:
            lats = ds.lat.values
            lons = ds.lon.values
        else:
            print(f"Warning: Expected dimensions not found in {file_path}")
            return None
            
        ds.close()
        return irrigated_area, lats, lons
        
    except Exception as e:
        print(f"Error processing {file_path}: {str(e)}")
        return None

# Initialize arrays to store sums
main_crop_irrigated_area = None
all_crop_irrigated_area = None
lats = None
lons = None

# Dictionary to store individual main crop irrigated areas
main_crop_data = {}

# First, process all crops to get total irrigated area
print("Calculating total irrigated area for all crops...")
for crop in all_crops:
    file_path = os.path.join(input_path, f"{crop}_HA_Irri_05d.nc")
    
    result = calculate_irrigated_area(file_path)
    if result is None:
        continue
        
    irrigated_area, crop_lats, crop_lons = result
    
    # Store coordinates from first file
    if lats is None:
        lats = crop_lats
        lons = crop_lons
    
    # Initialize or add to the sum
    if all_crop_irrigated_area is None:
        all_crop_irrigated_area = irrigated_area
    else:
        all_crop_irrigated_area += irrigated_area
    
    # Store individual main crop data and add to main crop sum
    if crop in main_crops:
        # Store the individual main crop data
        main_crop_data[crop] = irrigated_area
        
        # Also add to main crop sum
        if main_crop_irrigated_area is None:
            main_crop_irrigated_area = irrigated_area
        else:
            main_crop_irrigated_area += irrigated_area
        print(f"Added {crop} to main crop sum")

# Check if we have valid data
if main_crop_irrigated_area is None or all_crop_irrigated_area is None:
    print("Error: Could not calculate irrigated areas")
    exit(1)

# Handle missing main crops by creating zero arrays
for crop in main_crops:
    if crop not in main_crop_data:
        print(f"Creating zero array for missing crop: {crop}")
        main_crop_data[crop] = xr.zeros_like(all_crop_irrigated_area)

# Calculate the fraction: main_crops / all_crops
print("Calculating main crop fraction...")
# Avoid division by zero by creating a mask
mask = (all_crop_irrigated_area > 0)
main_crop_fraction = xr.zeros_like(all_crop_irrigated_area)
main_crop_fraction = main_crop_fraction.where(~mask, main_crop_irrigated_area / all_crop_irrigated_area)

# Create a dataset with variables for each main crop
dataset_dict = {
    "Main_Crop_Irrigated_Area": (["lat", "lon"], main_crop_irrigated_area.values),
    "All_Crop_Irrigated_Area": (["lat", "lon"], all_crop_irrigated_area.values),
    "Frac_MainCrop": (["lat", "lon"], main_crop_fraction.values),
}

# Add individual main crop variables
for crop in main_crops:
    var_name = f"{crop}_Irrigated_Area"
    dataset_dict[var_name] = (["lat", "lon"], main_crop_data[crop].values)

# Create the dataset
result_ds = xr.Dataset(
    dataset_dict,
    coords={
        "lat": lats,
        "lon": lons
    }
)

# Add attributes
result_ds["Main_Crop_Irrigated_Area"].attrs = {
    "units": "ha",
    "long_name": "Irrigated area for main crops (RICE, WHEA, MAIZ, SOYB)",
    "_FillValue": np.nan
}

result_ds["All_Crop_Irrigated_Area"].attrs = {
    "units": "ha",
    "long_name": "Irrigated area for all crops",
    "_FillValue": np.nan
}

result_ds["Frac_MainCrop"].attrs = {
    "units": "fraction",
    "long_name": "Fraction of irrigated area occupied by main crops",
    "main_crops": "RICE, WHEA, MAIZ, SOYB",
    "_FillValue": np.nan
}

# Add attributes for individual main crop variables
for crop in main_crops:
    var_name = f"{crop}_Irrigated_Area"
    result_ds[var_name].attrs = {
        "units": "ha",
        "long_name": f"Irrigated area for {crop}",
        "_FillValue": np.nan
    }

# Save the result
output_file = os.path.join(output_path, "MainCrop_Fraction_05d.nc")
encoding = {
    "Main_Crop_Irrigated_Area": {"zlib": True, "complevel": 5},
    "All_Crop_Irrigated_Area": {"zlib": True, "complevel": 5},
    "Frac_MainCrop": {"zlib": True, "complevel": 5}
}

# Add encoding for individual main crop variables
for crop in main_crops:
    var_name = f"{crop}_Irrigated_Area"
    encoding[var_name] = {"zlib": True, "complevel": 5}

result_ds.to_netcdf(output_file, encoding=encoding)
print(f"Saved: {output_file}")