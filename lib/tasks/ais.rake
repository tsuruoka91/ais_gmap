namespace :ais do
  desc "Stream AIS position reports from AISStream.io and store them in the database"
  task ingest: :environment do
    require "eventmachine"

    Rails.logger = ActiveSupport::Logger.new($stdout) if ENV["AIS_LOG_STDOUT"] != "false"

    puts "[AIS] Starting AIS ingestion. Press Ctrl-C to stop."

    EM.run do
      client = AisStreamClient.new
      client.start

      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          puts "\n[AIS] Received #{signal}, shutting down ..."
          EM.stop
        end
      end
    end
  end
end
