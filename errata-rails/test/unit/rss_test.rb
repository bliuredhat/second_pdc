require 'test_helper'

class RssTest < ActiveSupport::TestCase
  test "gen rss" do
    ids = Errata.connection.select_values("select id from  #{Errata.table_name}")
    ids.each do |id| 
      assert_nothing_raised("Unexpected error for #{id}") {ErrataRss.gen_rss id }
    end
  end

  test "gen opml" do
    ids = Release.connection.select_values("select id from  #{Release.table_name}")
    ids.each do |id| 
      assert_nothing_raised("Unexpected error for #{id}") {ErrataRss.write_opml id }
    end
    assert_nothing_raised("Problem regenerating web index") {ErrataRss.regenerate_web_index}
  end

  test "after advisory is created rss is generated" do
    data = {
      :reporter => qa_user,
      :synopsis => 'test 1',
      :product => Product.find_by_short_name('RHEL'),
      :release => async_release,
      :assigned_to => qa_user,
      :security_impact => 'Moderate',
      :content => Content.new(:topic => 'test',
                              :description => 'test',
                              :solution => 'fix it')
    }
    RssObserver.any_instance.expects(:after_create).times(3).with(kind_of(Errata))
    [RHBA, RHSA, RHEA].each do |klass|
      advisory = klass.create!(data)
    end
  end

  test "after advisory is updated RSS is updated" do
    RssObserver.any_instance.expects(:after_update).times(3).with(kind_of(Errata))
    [RHBA, RHSA, RHEA].each do |klass|
      klass.last.update_attribute(:synopsis, "different")
    end
  end

  test "rss baselines" do
    Socket.stubs(:gethostname => 'errata-unit-test')
    with_xml_baselines('errata_rss', /errata-(\d+)\.xml$/) do |_, et_id|
      ErrataRss.rss_for_errata(et_id.to_i).to_s
    end
  end
end
