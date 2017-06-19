require 'test_helper'

class BackgroundJobControllerTest < ActionController::TestCase

  test 'displays jobs paginated' do
    auth_as admin_user

    Delayed::Job.delete_all

    time = Time.now

    # make a lot of jobs
    (1..160).each do |i|
      time = time + 5.minutes
      Time.stubs(:now => time)
      "job _#{i}_".send_later(:reverse)
    end

    get :index
    assert_response :success

    # page should have rendered first part of jobs only
    body = response.body
    assert_match /job _1_/, body
    assert_match /job _2_/, body
    assert_no_match /job _150_/, body

    # can get the next page
    get :index, :page => 2
    assert_response :success

    body = response.body
    assert_no_match /job _1_/, body
    assert_no_match /job _2_/, body
    assert_match /job _150_/, body
  end
end
