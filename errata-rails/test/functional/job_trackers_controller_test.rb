require 'test_helper'

class JobTrackersControllerTest < ActionController::TestCase
  setup do
    @name = 'My job tracker'
    @desc = 'Track a bunch of jobs'
    @job_tracker = JobTracker.track_jobs(@name, @desc) do
      # (send_later makes a delayed job. don't care what it is)
      @job = Product.send_later(:last)
    end
    assert_equal [@job], @job_tracker.delayed_jobs
    auth_as devel_user
  end

  test "index" do
    get :index
    assert_response :success
    assert_select 'td', @name
    assert_select 'td', @desc
    assert_select 'td', 'RUNNING'
  end

  test 'index paginates' do
    (1..500).each do |i|
      JobTracker.track_jobs("job -#{i}-", 'test') do
        Product.send_later(:last)
      end
    end

    get :index
    assert_response :success

    # It should be displaying most recently created jobs, not the older ones
    assert_select 'td', 'job -500-'
    assert_select 'td', 'job -499-'

    assert_select 'td', :text => 'job -200-', :count => 0
    assert_select 'td', :text => 'job -2-', :count => 0
    assert_select 'td', :text => 'job -1-', :count => 0

    # Next page should display others
    get :index, :page => 2
    assert_response :success

    assert_select 'td', 'job -200-'

    assert_select 'td', :text => 'job -2-', :count => 0
    assert_select 'td', :text => 'job -1-', :count => 0
  end

  test "show" do
    get :show, :id => @job_tracker.id
    assert_response :success
    assert_select 'h1', "#{@name} - #{@desc} - RUNNING"
    assert_select 'p', "There are 1 jobs left to run."
  end
end
