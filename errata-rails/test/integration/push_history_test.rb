require 'test_helper'

class PushHistoryTest < ActionDispatch::IntegrationTest
  setup do
    auth_as releng_user
  end

  test 'nochannel shown in push history' do
    errata = Errata.find(19029)
    nochannel_job = RhnLivePushJob.find(47971)
    stage_job = RhnStagePushJob.find(34510)

    assert_equal errata, nochannel_job.errata
    assert_equal errata, stage_job.errata

    visit "/push/push_history_for_errata/#{errata.id}"

    within push_job_row(nochannel_job) do
      assert has_text?('rhn_live')
      assert has_text?(nochannel_job.status)
      # since a completed nochannel rhn live job has a very different meaning than a
      # completed regular rhn live job, it's highlighted in the UI
      assert has_css?('.label', :text => 'nochannel')
    end

    within push_job_row(stage_job) do
      assert has_text?('rhn_stage')
      assert has_text?(stage_job.status)
      refute has_text?('nochannel')
    end
  end

  def push_job_row(job)
    find :xpath, "//tr[.//*[contains(text(), '#{job.id}')]]"
  end
end
