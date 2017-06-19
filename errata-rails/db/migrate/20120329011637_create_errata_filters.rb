class CreateErrataFilters < ActiveRecord::Migration
  def self.up
    create_table :errata_filters do |t|
      t.string     :type, :null => false # Using STI, can be UserErrataFilter or SystemErrataFilter
      t.string     :name, :null => false
      t.text       :filter_params # will be serialized, use text just in case it gets really big...
      t.references :user # can be nil (is nil for system filter)
      t.timestamps
    end
  end

  def self.down
    drop_table :errata_filters
  end
end
