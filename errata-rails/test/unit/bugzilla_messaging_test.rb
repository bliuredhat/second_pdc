require 'test_helper'
require 'test_messenger'

class BugzillaMessagingTest < ActiveSupport::TestCase

  test "don't crash on invalid message" do
    Settings.mbus_bugzilla_sync_enabled = true
    test_bz_messages(['some garbage', 'not the right format'])
  end

  test "update and create mix" do
    Settings.mbus_bugzilla_sync_enabled = true
    # cycle tests that we don't break on duplicates
    ids = [1, 2, 3, 130358, 131142, 145121].cycle(2).to_a

    # Clean all existing dirty bugs before proceeding the test
    DirtyBug.delete_all

    test_bz_messages(
      ids.map{|i| {:bug_id => i}.to_json}
    )

    # Out-dated existing bugs should be marked as dirty
    Bug.find(ids.select{|i| i > 100}).each do |bug|
      assert bug.dirty?
    end

    # and other bugs should not have been created yet,
    # but should be marked as dirty bug.
    ids.select{|i| i < 100}.each do |id|
      refute Bug.exists? id
      assert DirtyBug.exists?(:record_id => id)
    end
  end

  def test_bz_messages(bodies)
    address = 'queue://errata_from_esb'
    props = {'esbSourceSystem' => 'bugzilla',
             'esbMessageType' => 'bugzillaNotification'}
    messages = bodies.map do |b|
      TestMessage.new(address, b, props)
    end
    TestMessenger.test_messages(messages)
  end

end
