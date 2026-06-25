class Vessel < ApplicationRecord
  validates :mmsi, presence: true, uniqueness: true

  scope :recent, ->(minutes = 10) { where(last_message_at: minutes.to_i.minutes.ago..) }

  # Upsert latest position for a vessel keyed by MMSI.
  def self.record_position!(attrs)
    mmsi = attrs[:mmsi]
    return if mmsi.blank?

    vessel = find_or_initialize_by(mmsi: mmsi)
    vessel.assign_attributes(attrs)
    vessel.name = attrs[:name] if attrs[:name].present?
    vessel.save!
    vessel
  end
end
