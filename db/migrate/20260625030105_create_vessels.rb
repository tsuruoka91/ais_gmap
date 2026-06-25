class CreateVessels < ActiveRecord::Migration[8.0]
  def change
    create_table :vessels do |t|
      t.integer :mmsi
      t.string :name
      t.float :latitude
      t.float :longitude
      t.float :sog
      t.float :cog
      t.integer :true_heading
      t.integer :nav_status
      t.integer :ship_type
      t.datetime :last_message_at

      t.timestamps
    end
    add_index :vessels, :mmsi, unique: true
    add_index :vessels, :last_message_at
  end
end
