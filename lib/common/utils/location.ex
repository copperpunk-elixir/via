defmodule Common.Utils.Location do
  require Logger

  @pi_4 0.785398163
  @earth_radius_m 6371008.8

  @spec dx_dy_between_points(struct(), struct()) :: tuple()
  def dx_dy_between_points(wp1, wp2) do
    lat1 = wp1.latitude
    lat2 = wp2.latitude
    dpsi = :math.log(:math.tan(@pi_4 + lat2/2)/ :math.tan(@pi_4 + lat1/2))
    dlat = lat2 - lat1
    dlon = wp2.longitude - wp1.longitude
    q =
    if (abs(dpsi) > 0.0000001) do
      dlat/dpsi
    else
      :math.cos(lat1)
    end
    {dlat*@earth_radius_m, q*dlon*@earth_radius_m}
  end

  @spec dx_dy_between_points(float(), float(), float(), float()) :: tuple()
  def dx_dy_between_points(lat1, lon1, lat2, lon2) do
    dx_dy_between_points(Common.Utils.LatLonAlt.new(lat1, lon1), Common.Utils.LatLonAlt.new(lat2, lon2))
  end

  @spec lla_from_point(struct(), float(), float()) :: struct()
  def lla_from_point(origin, dx, dy) do
    lat1 = origin.latitude
    lon1 = origin.longitude
    dlat = dx/@earth_radius_m
    lat2 = lat1 + dlat
    dpsi = :math.log(:math.tan(@pi_4 + lat2/2)/ :math.tan(@pi_4 + lat1/2))
    q =
    if (abs(dpsi) > 0.0000001) do
      dlat/dpsi
    else
      :math.cos(lat1)
    end
    dlon = (dy/@earth_radius_m) / q
    lon2 = lon1 + dlon
    # {lat2, lon2}
    Common.Utils.LatLonAlt.new(lat2, lon2, origin.altitude)
  end

  @spec lla_from_point(struct(), tuple()) :: struct()
  def lla_from_point(origin, point) do
    {dx, dy} = point
    lla_from_point(origin, dx, dy)
  end

  @spec lla_from_point_with_distance(struct(), float(), float()) :: struct()
  def lla_from_point_with_distance(lat_lon_alt, distance, bearing) do
    dx = distance*:math.cos(bearing)
    dy = distance*:math.sin(bearing)
    # Logger.debug("dx/dy: #{dx}/#{dy}")
    lla_from_point(lat_lon_alt, dx, dy)
  end

  # @spec lla_from_point_with_distance(float(), float(), float(), float()) :: tuple()
  # def lla_from_point_with_distance(lat1, lon1, distance, bearing) do
  #   dx = distance*:math.cos(bearing)
  #   dy = distance*:math.sin(bearing)
  #   lla_from_point(lat1, lon1, dx, dy)
  # end

end
