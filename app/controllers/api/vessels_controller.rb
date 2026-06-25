module Api
  class VesselsController < ApplicationController
    DEFAULT_MINUTES = 10
    DEFAULT_LIMIT = 2000

    def index
      minutes = params.fetch(:minutes, DEFAULT_MINUTES).to_i.clamp(1, 1440)
      limit = params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, 10_000)

      vessels = Vessel
        .recent(minutes)
        .where.not(latitude: nil, longitude: nil)
        .order(last_message_at: :desc)
        .limit(limit)

      vessels = within_bounds(vessels)

      render json: vessels.map { |v| serialize(v) }
    end

    private

    # Restrict to the map's visible bounding box when all edges are provided.
    def within_bounds(relation)
      north = float_param(:north)
      south = float_param(:south)
      east  = float_param(:east)
      west  = float_param(:west)
      return relation unless [north, south, east, west].all?

      relation = relation.where(latitude: south..north)
      if west <= east
        relation.where(longitude: west..east)
      else
        # Bounding box crosses the antimeridian (180/-180).
        relation.where("longitude >= ? OR longitude <= ?", west, east)
      end
    end

    def float_param(key)
      value = params[key]
      return nil if value.blank?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def serialize(vessel)
      {
        mmsi: vessel.mmsi,
        name: vessel.name,
        latitude: vessel.latitude,
        longitude: vessel.longitude,
        sog: vessel.sog,
        cog: vessel.cog,
        true_heading: vessel.true_heading,
        nav_status: vessel.nav_status,
        last_message_at: vessel.last_message_at&.iso8601
      }
    end
  end
end
