class UpdateCcatUrls < ActiveRecord::Migration
  def up
    update(
      'http://nest.test.redhat.com/mnt/qa/content_test_results/ccat/errata/$ID/logs/$ERRATA_ID-results.html',
      'https://mojo.redhat.com/docs/DOC-1051013')
  end

  def down
    update(
      'https://content-test-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/job/cdn_content_validation/$ID/',
      'https://mojo.redhat.com/docs/DOC-165446')
  end

  def update(run_url, info_url)
    ExternalTestType.where(:name => 'ccat').update_all(
      :prod_run_url => run_url,
      :test_run_url => run_url,
      :info_url     => info_url)
  end
end
