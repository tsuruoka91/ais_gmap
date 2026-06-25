module Api
  class ViewportController < ApplicationController
    # Return the bounding boxes currently being ingested.
    def show
      render json: { bounding_boxes: AisViewport.read || [] }
    end

    # Receive the current map bounds and persist them as the area to ingest.
    def update
      north = Float(params[:north])
      south = Float(params[:south])
      east  = Float(params[:east])
      west  = Float(params[:west])

      boxes =
        if west <= east
          [[[south, west], [north, east]]]
        else
          # Viewport crosses the antimeridian; split into two boxes.
          [[[south, west], [north, 180.0]], [[south, -180.0], [north, east]]]
        end

      AisViewport.write(boxes)
      head :no_content
    rescue ArgumentError, TypeError
      head :bad_request
    end
  end
end
