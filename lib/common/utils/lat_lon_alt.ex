defmodule Common.Utils.LatLonAlt do
  require Logger
  @enforce_keys [:latitude_rad, :longitude_rad, :altitude_m]
  defstruct [:latitude_rad, :longitude_rad, :altitude_m]

  @spec new(float(), float(), float()) :: struct()
  def new(lat, lon, alt) do
    %Common.Utils.LatLonAlt{
      latitude_rad: lat,
      longitude_rad: lon,
      altitude_m: alt
    }
  end

  @spec new(float(), float()) :: struct()
  def new(lat, lon) do
    new(lat, lon, 0)
  end

  @spec new_deg(float(), float(), float()) :: struct()
  def new_deg(lat, lon, alt) do
    new(Common.Utils.Math.deg2rad(lat),Common.Utils.Math.deg2rad(lon),alt)
  end

  @spec new_deg(float(), float()) :: struct()
  def new_deg(lat, lon) do
    new(Common.Utils.Math.deg2rad(lat),Common.Utils.Math.deg2rad(lon),0)
  end

  @spec to_string(struct()) :: binary()
  def to_string(lla) do
    lat_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.latitude_rad), 5)
    lon_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.longitude_rad), 5)
    alt_str = Common.Utils.eftb(lla.altitude_m, 1)
    "lat/lon/alt: #{lat_str}/#{lon_str}/#{alt_str}"
  end
end
