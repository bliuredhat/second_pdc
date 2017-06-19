class PrepareRpmDiffResultDetails < ActiveRecord::Migration
  def up
    create_table :rpmdiff_result_details, :primary_key => 'result_detail_id' do |t|
      t.string :subpackage, :limit => 1000
      t.integer :score, :null => false
      t.foreign_key ['score'], 'rpmdiff_scores', ['id']
      t.text :content, :null => false
      t.integer :result_id, :null => false
      t.foreign_key ['result_id'], 'rpmdiff_results', ['result_id']
    end
  end

  def down
    drop_table :rpmdiff_result_details
  end

end
