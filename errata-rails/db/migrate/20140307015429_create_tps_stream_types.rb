class CreateTpsStreamTypes < ActiveRecord::Migration
  def change
    create_table :tps_stream_types, :description => 'A list of available stream types in TPS server' do |t|
      t.string 'name', :null => false, :description => "Name of the tps stream type"
    end

    # Add initial data
    ["Z", "LL", "ELS", "AUS"].each do |s|
      TpsStreamType.create(:name => s)
    end
  end
end
