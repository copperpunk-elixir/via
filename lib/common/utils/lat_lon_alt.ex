defmodule Common.Utils.LatLonAlt do
  require Logger
  @enforce_keys [:latitude, :longitude, :altitude]
  defstruct [:latitude, :longitude, :altitude]

  @spec new(float(), float(), float()) :: struct()
  def new(lat, lon, alt) do
    %Common.Utils.LatLonAlt{
      latitude: lat,
      longitude: lon,
      altitude: alt
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
    lat_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.latitude), 5)
    lon_str = Common.Utils.eftb(Common.Utils.Math.rad2deg(lla.longitude), 5)
    alt_str = Common.Utils.eftb(lla.altitude, 1)
    "lat/lon/alt: #{lat_str}/#{lon_str}/#{alt_str}"
  end
end
