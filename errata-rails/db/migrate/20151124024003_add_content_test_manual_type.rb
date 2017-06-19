class AddContentTestManualType < ActiveRecord::Migration
  RESULT_URL = 'http://nest.test.redhat.com/mnt/qa/content_test_results/ccat/manual/$ID/logs/$ERRATA_ID-results.html'
  DOC_URL = 'https://mojo.redhat.com/docs/DOC-1051013'

  def up
    ExternalTestType.create!(
      :name         => 'ccat/manual',
      :tab_name     => 'CCAT',
      :display_name => 'CDN Content Availability (manual)',
      :prod_run_url => RESULT_URL,
      :test_run_url => RESULT_URL,
      :info_url     => DOC_URL,
      :active       => true,
      :sort_key     => 11)
  end

  def down
    type = ExternalTestType.where(:name => 'ccat/manual')
    ExternalTestRun.where(:external_test_type_id => type).delete_all
    type.delete_all
  end
end
