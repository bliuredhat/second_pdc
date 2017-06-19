class AddContentTestType < ActiveRecord::Migration
  JENKINS_URL = 'https://content-test-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/cdn_content_validation/$ID/'

  def up
    ExternalTestType.create!(
      :name         => 'ccat',
      :tab_name     => 'CCAT',
      :display_name => 'CDN Content Availability',
      :prod_run_url => JENKINS_URL,
      :test_run_url => JENKINS_URL,
      :info_url     => 'https://mojo.redhat.com/docs/DOC-165446',
      :active       => true,
      :sort_key     => 10)
  end

  def down
    type = ExternalTestType.where(:name => 'ccat')
    ExternalTestRun.where(:external_test_type_id => type).delete_all
    type.delete_all
  end
end
