import os
import numpy as np
import rasterio
import xarray as xr
from scipy.interpolate import griddata

# Path for the original fertilization data
input_path = '/lustre/nobackup/WUR/ESG/zhou111/Data/Raw/HarvestArea/spam2005/geotiff_global'
output_path = "/lustre/nobackup/WUR/ESG/zhou111/Data/Havest_Area"
crop_list = ["ACOF", "BANA", "BARL", "BEAN", "CASS", "CHIC", "CNUT", "COCO", "COTT", "COWP", "GROU", "LENT", "MAIZ", "OCER", "OFIB", "OILP", "OOIL", "ORTS", "PIGE", "PLNT", "PMIL", "POTA", "RAPE", "RCOF", "REST", "RICE", "SESA", "SMIL", "SORG", "SUGB", "SUGC", "SUNF", "SWPO", "TEAS", "TEMF", "TOBA", "TROF", "VEGE", "WHEA", "YAMS"]
lon_new = np.arange(-179.75, 180, 0.5)
lat_new = np.arange(89.75, -90, -0.5)
lon_grid, lat_grid = np.meshgrid(lon_new, lat_new)

def read_and_interpolate_raster(file_path):
    with rasterio.open(file_path) as src:
         data = src.read(1)
         transform = src.transform
         height, width = data.shape

         # Get lat/lon of original raster
         cols, rows = np.meshgrid(np.arange(width), np.arange(height))
         xs, ys = rasterio.transform.xy(transform, rows, cols)
         lon_orig = np.array(xs)
         lat_orig = np.array(ys)

         # Flatten for interpolation
         points = np.vstack((lon_orig.ravel(), lat_orig.ravel())).T
         values = data.ravel()

         # Remove nodata
         valid = (values > -1e3) & (values < 1e3)
         values = values[valid]
         points = points[valid]

         # Interpolate to 0.5° grid
         data_interp = griddata(points, values, (lon_grid, lat_grid), method='linear')
         data_interp = np.where(np.isnan(data_interp), -9999.0, data_interp)  # Fill missing

         return data_interp


for crop in crop_list:
    HA_file = os.path.join(input_path, f"SPAM2005V3r2_global_H_TA_{crop}_A.tif")
    Irri_file = os.path.join(input_path, f"SPAM2005V3r2_global_H_TA_{crop}_I.tif")

    HA_interp = read_and_interpolate_raster(HA_file)
    Irri_interp = read_and_interpolate_raster(Irri_file)

    ds = xr.Dataset(
        {
            "Harvest Area": (["lat", "lon"], HA_interp),
            "Irrigated Proportion": (["lat", "lon"], Irri_interp),
        },
        coords={
            "lon": lon_new,
            "lat": lat_new
        },
    )
    ds["Harvest Area"] = ds["Harvest Area"].where(~np.isnan(ds["Harvest Area"]))
    ds["Irrigated Proportion"] = ds["Irrigated Proportion"].where(~np.isnan(ds["Irrigated Proportion"]))

    # Save NetCDF
    nc_file = os.path.join(output_path, f"{crop}_HA_Irri_05d.nc")
    ds.to_netcdf(nc_file)
    print(f"Saved: {nc_file}")