require 'test_helper'

class FtpPushJobTest  < ActiveSupport::TestCase
  test "ftp push job" do 
    job = FtpPushJob.new(:errata => rhba_async, :pushed_by => qa_user)
    assert !job.valid?
    assert !job.can_push?
    job.pub_options[:foo] = :bar
    assert !job.valid?
  end
end
