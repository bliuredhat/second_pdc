class CreatePdcResources < ActiveRecord::Migration

  def change
    create_table :pdc_resources do |t|
      t.string :type, :null => false
      t.string :pdc_id, :null => false, :index => true

      t.timestamps
    end
  end

end
