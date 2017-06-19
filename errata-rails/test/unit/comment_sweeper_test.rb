require 'test_helper'

class CommentSweeperTest < ActiveSupport::TestCase

  test "get delivery method" do

    sweepers = Comment.observer_instances.select { |x| x.is_a? CommentSweeper }
    assert_equal 1, sweepers.count

    params = { :controller => :errata, :action => :change_state }
    controller = mock('Controller')
    controller.expects(:params).returns(params)
    CommentSweeper.any_instance.stubs(:controller).at_least_once.returns(controller)
    CommentSweeper.any_instance.stubs(:params).at_least_once.returns(params)

    result = sweepers.first.send(:get_delivery_method)
    assert_equal [:errata, :change_state].join('_'), result
  end

  test "disable comment observer" do
    # NOTE: need to store Comment.last as disabled_notification
    # is not persisted, so
    #   Comment.last.disabled_notification = true
    #   assert_equal true, Comment.last.disabled_notification
    #
    # FAILS because Comment.last returns different object
    # for each invocation
    last_comment = Comment.last
    last_comment.disabled_notification = true

    CommentSweeper.any_instance.expects(:mail_comment).never
    Comment.notify_observers :after_commit, last_comment
  end

end
