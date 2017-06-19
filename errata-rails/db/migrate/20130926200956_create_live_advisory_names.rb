class CreateLiveAdvisoryNames < ActiveRecord::Migration
  def self.up
    create_table :live_advisory_names do |t|
      t.integer :errata_id, :null => false
      t.integer :year, :null => false
      t.integer :live_id, :null => false
      t.timestamps
    end
    add_index :live_advisory_names, :errata_id, :unique => true
    add_index :live_advisory_names, [:year, :live_id], :unique => true

    Errata.shipped_live.each do |e|
      year, id = e.shortadvisory.split(':')
      next if id == '0382B'
      la = LiveAdvisoryName.new(:errata => e, :year => year.to_i, :live_id => id.to_i).save
    end
    Errata.active.where('errata_id < 7000').each do |e|
      year, id = e.shortadvisory.split(':')
      la = LiveAdvisoryName.new(:errata => e, :year => year.to_i, :live_id => id.to_i).save
    end

  end

  def self.down
    remove_index :live_advisory_names, :errata_id
    remove_index :live_advisory_names, [:year, :live_id]
    drop_table :live_advisory_names
  end
end
