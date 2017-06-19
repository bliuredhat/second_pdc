class Publications < ActiveRecord::Migration
  def self.up
    create_table :publications, 
    :description => "Abstract list of things that are published" do |t|
      t.column "type", :string, :null => false, 
      :description => "Type of the task"
      t.column "last_published_at", :datetime, :null => false, 
      :description => "Date the resource was last published"
      t.column "is_out_of_date", :integer, :null => false, :default => 0,
      :description => "Set to true by webserver if resource is out of date and requires publication"
    end
  end

  def self.down
    drop_table :publications
  end
end
