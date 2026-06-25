class MapController < ApplicationController
  def index
    @google_maps_api_key = ENV["GOOGLE_MAPS_API_KEY"]
    # AdvancedMarkerElement requires a Map ID. Falls back to Google's test ID.
    @google_maps_map_id = ENV["GOOGLE_MAPS_MAP_ID"].presence || "DEMO_MAP_ID"
    @map_center = map_center
  end

  private

  # Center the map on the middle of the configured bounding box.
  def map_center
    boxes = AisStreamClient.configured_bounding_boxes
    coords = boxes.flatten(1)
    lats = coords.map { |c| c[0] }
    lons = coords.map { |c| c[1] }
    {
      lat: (lats.min + lats.max) / 2.0,
      lng: (lons.min + lons.max) / 2.0
    }
  rescue
    { lat: 35.35, lng: 139.85 }
  end
end
