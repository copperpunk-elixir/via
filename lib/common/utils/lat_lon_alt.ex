defmodule Common.Utils.LatLonAlt do
  require Logger
  @enforce_keys [:latitude_rad, :longitude_rad, :altitude_m]
  defstruct [:latitude_rad, :longitude_rad, :altitude_m]

  @spec new(number(), number(), number()) :: struct()
  def new(lat, lon, alt) do
    %Common.Utils.LatLonAlt{
      latitude_rad: lat,
      longitude_rad: lon,
      altitude_m: alt
    }
  end

  @spec new(number(), number()) :: struct()
  def new(lat, lon) do
    new(lat, lon, 0)
  end

  @spec new_deg(number(), number(), number()) :: struct()
  def new_deg(lat, lon, alt) do
    new(UtilsMath.deg2rad(lat), UtilsMath.deg2rad(lon), alt)
  end

  @spec new_deg(number(), number()) :: struct()
  def new_deg(lat, lon) do
    new(UtilsMath.deg2rad(lat), UtilsMath.deg2rad(lon), 0)
  end

  @spec to_string(struct()) :: binary()
  def to_string(lla) do
    lat_str = UtilsFormat.eftb(UtilsMath.rad2deg(lla.latitude_rad), 5)
    lon_str = UtilsFormat.eftb(UtilsMath.rad2deg(lla.longitude_rad), 5)
    alt_str = UtilsFormat.eftb(lla.altitude_m, 1)
    "lat/lon/alt: #{lat_str}/#{lon_str}/#{alt_str}"
  end
end
