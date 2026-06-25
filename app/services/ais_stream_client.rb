require "faye/websocket"
require "eventmachine"
require "json"

# Connects to AISStream.io over WebSocket, subscribes to PositionReport
# messages for a configured bounding box, and upserts vessel positions.
#
# Usage (inside an EventMachine reactor):
#   EM.run { AisStreamClient.new.start }
class AisStreamClient
  AIS_STREAM_URL = "wss://stream.aisstream.io/v0/stream".freeze

  # Default bounding box covers Tokyo Bay. Override with AIS_BBOX env var,
  # formatted as JSON, e.g. "[[[35.0,139.5],[35.7,140.2]]]".
  DEFAULT_BOUNDING_BOXES = [[[35.0, 139.5], [35.7, 140.2]]].freeze

  RECONNECT_DELAY = 5 # seconds

  def initialize(api_key: ENV["AISSTREAM_API_KEY"], bounding_boxes: self.class.configured_bounding_boxes, logger: Rails.logger)
    @api_key = api_key
    @bounding_boxes = bounding_boxes
    @logger = logger
    @message_count = 0
  end

  def self.configured_bounding_boxes
    raw = ENV["AIS_BBOX"]
    return DEFAULT_BOUNDING_BOXES if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError => e
    Rails.logger.warn("[AIS] Invalid AIS_BBOX env var (#{e.message}); using default bounding box")
    DEFAULT_BOUNDING_BOXES
  end

  def start
    if @api_key.blank?
      @logger.error("[AIS] AISSTREAM_API_KEY is not set. Aborting ingestion.")
      EM.stop if EM.reactor_running?
      return
    end

    connect
  end

  private

  def connect
    @logger.info("[AIS] Connecting to #{AIS_STREAM_URL} ...")
    ws = Faye::WebSocket::Client.new(AIS_STREAM_URL)

    ws.on(:open) { |_event| handle_open(ws) }
    ws.on(:message) { |event| handle_message(event) }
    ws.on(:close) { |event| handle_close(event) }
    ws.on(:error) { |event| @logger.error("[AIS] WebSocket error: #{event.message}") }
  end

  def handle_open(ws)
    @logger.info("[AIS] Connected. Subscribing to bounding boxes: #{@bounding_boxes.inspect}")
    subscription = {
      APIKey: @api_key,
      BoundingBoxes: @bounding_boxes,
      FilterMessageTypes: ["PositionReport"]
    }
    ws.send(subscription.to_json)
  end

  def handle_message(event)
    data = JSON.parse(event.data)

    if data["error"].present?
      @logger.error("[AIS] Server error: #{data['error']}")
      return
    end

    return unless data["MessageType"] == "PositionReport"

    report = data.dig("Message", "PositionReport") || {}
    metadata = data["MetaData"] || {}

    attrs = {
      mmsi: metadata["MMSI"] || report["UserID"],
      name: metadata["ShipName"]&.strip,
      latitude: report["Latitude"],
      longitude: report["Longitude"],
      sog: report["Sog"],
      cog: report["Cog"],
      true_heading: report["TrueHeading"],
      nav_status: report["NavigationalStatus"],
      last_message_at: parse_time(metadata["time_utc"])
    }

    Vessel.record_position!(attrs)
    @message_count += 1
    @logger.info("[AIS] Stored #{@message_count} position reports (latest MMSI #{attrs[:mmsi]})") if (@message_count % 50).zero?
  rescue JSON::ParserError => e
    @logger.warn("[AIS] Failed to parse message: #{e.message}")
  rescue => e
    @logger.error("[AIS] Failed to store message: #{e.class}: #{e.message}")
  end

  def handle_close(event)
    @logger.warn("[AIS] Connection closed (code=#{event.code}, reason=#{event.reason}). Reconnecting in #{RECONNECT_DELAY}s ...")
    EM.add_timer(RECONNECT_DELAY) { connect }
  end

  def parse_time(value)
    return Time.current if value.blank?

    Time.parse(value)
  rescue ArgumentError
    Time.current
  end
end
