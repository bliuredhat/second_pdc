class CreateTpsVariants < ActiveRecord::Migration
  def change
    create_table :tps_variants, :description => 'A list of available variants in TPS server' do |t|
      t.string 'name', :null => false, :description => "Name of the tps variant"
    end

    # Add initial data
    ["AS", "Client", "Server", "Workstation", "ComputeNode", "WebServer", "ES", "WS", "Desktop"].each do |v|
      TpsVariant.create(:name => v)
    end
  end
end
