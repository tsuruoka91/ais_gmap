require "json"

# Shared, cross-process store for the currently displayed map viewport.
#
# The web process writes the latest map bounds here (as AISStream-style
# bounding boxes) and the ingestion process reads it to decide which area to
# subscribe to. A plain JSON file is used so the two separate processes can
# share state without extra infrastructure.
class AisViewport
  PATH = Rails.root.join("tmp", "ais_viewport.json")

  class << self
    # Persist the desired bounding boxes atomically.
    # boxes format: [[[swLat, swLon], [neLat, neLon]], ...]
    def write(boxes)
      payload = { "bounding_boxes" => boxes, "updated_at" => Time.current.iso8601 }
      tmp = "#{PATH}.#{Process.pid}.tmp"
      File.write(tmp, JSON.generate(payload))
      File.rename(tmp, PATH)
      boxes
    end

    # Return the stored bounding boxes, or nil when unset/invalid.
    def read
      return nil unless File.exist?(PATH)

      data = JSON.parse(File.read(PATH))
      boxes = data["bounding_boxes"]
      boxes if boxes.is_a?(Array) && boxes.any?
    rescue JSON::ParserError, Errno::ENOENT
      nil
    end
  end
end
