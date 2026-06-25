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

      render json: vessels.map { |v| serialize(v) }
    end

    private

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
