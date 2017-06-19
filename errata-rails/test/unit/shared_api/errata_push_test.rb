require 'test_helper'

class SharedApi::ErrataPushTest < ActiveSupport::TestCase
  include SharedApi::ErrataPush

  setup do
    @errata = Errata.find(19030)
    assert_equal State::PUSH_READY, @errata.status
  end

  test 'modify default tasks and options' do
    params = {
      'target' => 'cdn',
      'append_pre_tasks' => ['reset_update_date'],
      'exclude_options' => ['push_metadata'],
      'exclude_post_tasks' => ['update_jira'],
      'append_options' => { 'priority' => 13 }
    }

    push_request = PushRequest.from_errata_and_params(@errata, params).first
    job = create_push_job_from_request(push_request)
    assert_equal false, job.pub_options['push_metadata']
    assert_equal 13, job.pub_options['priority']
    assert job.post_push_tasks.exclude? 'update_jira'
    assert job.pre_push_tasks.include? 'reset_update_date'
  end

  test 'tasks specified in append_pre_tasks and exclude_pre_tasks' do
    params = {
      'target' => 'cdn',
      'append_pre_tasks' => ['foo', 'bar', 'baz'],
      'exclude_pre_tasks' => ['bar', 'tab', 'foo'],
    }

    push_request = PushRequest.from_errata_and_params(@errata, params).first
    e = assert_raises(DetailedArgumentError) do
      create_push_job_from_request(push_request)
    end
    assert_equal 'exclude_pre_tasks has tasks also specified in append_pre_tasks: bar, foo', e.message
  end

  test 'tasks specified in append_post_tasks and exclude_post_tasks' do
    params = {
      'target' => 'cdn',
      'append_post_tasks' => ['foo', 'bar', 'baz'],
      'exclude_post_tasks' => ['bar', 'tab', 'foo'],
    }

    push_request = PushRequest.from_errata_and_params(@errata, params).first
    e = assert_raises(DetailedArgumentError) do
      create_push_job_from_request(push_request)
    end
    assert_equal 'exclude_post_tasks has tasks also specified in append_post_tasks: bar, foo', e.message
  end

  test 'options specified in append_options and exclude_options' do
    params = {
      'target' => 'cdn',
      'append_options' => ['foo', 'bar', 'baz'],
      'exclude_options' => ['bar', 'tab', 'foo'],
    }

    push_request = PushRequest.from_errata_and_params(@errata, params).first
    e = assert_raises(DetailedArgumentError) do
      create_push_job_from_request(push_request)
    end
    assert_equal 'exclude_options has options also specified in append_options: bar, foo', e.message
  end

  def create_push_job_from_request(push_request)
    target = push_request.targets.first
    user = User.find_by_login_name!('errata-test@redhat.com')
    with_current_user(user) { create_push_job(target, push_request) }
  end

end
