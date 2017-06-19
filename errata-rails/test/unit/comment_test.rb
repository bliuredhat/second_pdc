require 'test_helper'

class CommentTest < ActiveSupport::TestCase

  test "custom mail after state change" do
    commentcount = rhba_async.comments.count
    result = Comment.create_with_specified_notification_type(
      :tps_reschedule_all,
      {:errata => rhba_async, :text => 'foobar'})

    assert result.disabled_notification == true
    assert_equal commentcount + 1, rhba_async.comments.count

    CommentSweeper.any_instance.expects(:mail_comment).never
    # NOTE: can't use rhba_async.comments.last instead of result since
    # the objects are different and default value of
    # disabled_notification is nil (not disabled)
    Comment.notify_observers :after_commit, result
  end

  test "comment length increased" do
    max_length = 65535
    s = (['a'] * max_length).join
    assert_equal max_length, s.length
    e = Errata.last
    comment = e.comments.create(:text => s)
    assert_equal max_length, comment.reload.text.length
  end
end
