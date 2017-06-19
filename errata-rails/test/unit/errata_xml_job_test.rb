require 'test_helper'

class ErrataXmlJobTest < ActiveSupport::TestCase
  test "perform runs without errors" do
    et = RHSA.find(19435)
    assert et.shipped_live?
    assert et.is_security?

    xjob = Push::ErrataXmlJob.new(et)
    assert_nothing_raised do
      xjob.perform
    end
  end

  test "rhba runs without errors" do
    rhba = RHBA.find(20044)
    assert rhba.shipped_live?
    assert rhba.cve.present?

    xjob = Push::ErrataXmlJob.new(rhba)
    assert_nothing_raised do
      xjob.perform
    end
  end

  test "rhba with cve does get enqueued" do
    rhba = RHBA.find(20044)
    assert rhba.shipped_live?
    assert rhba.cve.present?
    assert Push::ErrataXmlJob::enqueue(rhba)
  end

  test "rhba without cve does not get enqueued" do
    rhba = RHBA.find(20466)
    assert rhba.shipped_live?
    assert rhba.cve.empty?
    refute Push::ErrataXmlJob::enqueue(rhba)
  end

end
