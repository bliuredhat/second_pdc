class CreateExternalTests < ActiveRecord::Migration
  def self.up
    create_table :external_test_types do |t|
      t.string  :name,         :null=>false, :unique=>true
      t.string  :display_name, :null=>false
      t.string  :prod_run_url, :null=>false
      t.string  :test_run_url
      t.string  :info_url
      t.boolean :active,       :default=>true, :null=>false
      t.integer :sort_key,     :default=>0
      t.timestamps
    end

    create_table :external_test_runs do |t|
      t.integer :external_test_type_id, :null=>false
      t.integer :errata_id,               :null=>false
      t.integer :brew_build_id
      t.boolean :active,                  :null=>false, :default=>true
      t.integer :superseded_by_id # another test run
      t.string  :status,                  :null=>false, :default=>'PENDING'
      t.integer :external_id
      t.string  :external_status
      t.string  :external_message
      t.timestamps
    end

    # Initially there's only one of these. Let's create it.
    ExternalTestType.create!({
      :name          => 'covscan',
      :display_name  => 'Coverity Scan',
      :prod_run_url  => 'http://cov01.lab.eng.brq.redhat.com/covscanhub/waiving/et_mapping/$ID/',
      :test_run_url  => 'http://uqtm.lab.eng.brq.redhat.com/covscan/waiving/et_mapping/$ID/',
      :info_url      => 'https://engineering.redhat.com/trac/CoverityScan/wiki',
    })

  end

  def self.down
    drop_table :external_test_types
    drop_table :external_test_runs
  end
end
