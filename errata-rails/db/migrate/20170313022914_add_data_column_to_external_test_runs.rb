class AddDataColumnToExternalTestRuns < ActiveRecord::Migration
  def change
    add_column :external_test_runs, :external_data, :text
  end
end
