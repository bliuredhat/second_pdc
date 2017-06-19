require 'test_helper'

class BlockingIssueControllerTest < ActionController::TestCase

  def setup
    auth_as devel_user
  end

  test "block issue can render template" do
    get :block_errata, :id => rhba_async.id
    assert_response :success
  end

  test "block issue" do
    assert_difference('BlockingIssue.count') do
      post :block_errata, :id => rhba_async.id,
        :blocking_issue => {
        :summary        => 'Writers block',
        :description    => "Can't think of anything new.",
        :role_name      => devel_user.roles.first.name,
      }
    end
    assert_response :redirect
    assert_not_nil  rhba_async.comments.last.blocking_issue
    assert          rhba_async.active_blocking_issue
  end

  test "unblock issue without active blocking issue" do
    post :unblock_errata, :id => rhba_async.id
    assert_response :redirect
    assert_match    /no active blocking issue/, flash[:alert]
  end

  test "unblock issue" do
    issue = BlockingIssue.create!(
      :summary       => 'Writers block',
      :description   => "Can't think of anything new",
      :blocking_role => devel_user.roles.first,
      :who           => devel_user,
      :errata        => rhba_async)

    assert_difference('Comment.count') do
      post :unblock_errata, :id => rhba_async.id
    end

    assert_response :redirect
    issue.reload
    refute issue.is_active
  end
end
