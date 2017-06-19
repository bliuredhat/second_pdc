require 'test_helper'

class LivePushTasksTest < ActiveSupport::TestCase
  include LivePushTasks

  setup do
    @info = []
  end

  def errata
    @errata
  end

  def info(msg)
    @info << msg
  end

  # Bug 1066840
  test 'request translation' do
    @errata = Errata.find(13147)
    assert @errata.is_security?

    Notifier.expects(:request_translation)\
      .with(@errata, regexp_matches(/\bID:\s+RHSA-2012:0987-04\b/))\
      .returns(mock('Object').tap{|o| o.stubs(:deliver => nil)})

    task_request_translation
  end
end
