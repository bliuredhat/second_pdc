require 'test_helper'

class TextOnlyChannelListTest < ActiveSupport::TestCase

  setup do
    @text_only = RHBA.create!(
      :reporter => qa_user,
      :synopsis => 'test 1',
      :product => Product.find_by_short_name('RHEL'),
      :release => async_release,
      :assigned_to => qa_user,
      :text_only => true,
      :content => Content.new(:topic => 'test',
                              :description => 'test',
                              :solution => 'fix it')
    )
    c1 = PrimaryChannel.create!(:name => 'foo',
                           :arch => Arch.find_by_name('i386'),
                           :variant => Variant.find_by_name('5Client'),
                           :product_version => ProductVersion.find_by_name('RHEL-5'))

    c2 = PrimaryChannel.create!(:name => 'bar',
                           :arch => Arch.find_by_name('ia64'),
                           :variant => Variant.find_by_name('5Client'),
                           :product_version => ProductVersion.find_by_name('RHEL-5'))
    @channels = [c1, c2]
  end

  test "successfully sets channels through accessor" do
    @text_only.text_only_channel_list.set_channels_by_id(@channels.map(&:id))
    @text_only.text_only_channel_list.save!

    e = Errata.find @text_only.id
    assert_equal e.text_only_channel_list.get_channels, @channels
  end

  test "raises error when saving wrong channels" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @text_only.text_only_channel_list.set_channels_by_id(['foo', nil])
    end
  end

  test "unsets channel list by passing nil" do
    advisory = Errata.find(10226)
    assert advisory.text_only_channel_list.channel_list.present?

    @text_only.text_only_channel_list.set_channels_by_id(nil)
    assert @text_only.text_only_channel_list.channel_list.empty?
    assert @text_only.text_only_channel_list.get_channels.empty?
  end

  test "successfully sets cdn repos through accessor" do
    @text_only.text_only_channel_list.set_cdn_repos_by_id([CdnRepo.last.id])
    @text_only.text_only_channel_list.save!

    assert_equal @text_only.text_only_channel_list.get_cdn_repos, [CdnRepo.last]
  end

  test "successfully unsets cdn_repos by passing nil" do
    advisory = Errata.find(10801)
    assert advisory.text_only_channel_list.cdn_repo_list.present?

    advisory.text_only_channel_list.set_cdn_repos_by_id(nil)
    assert advisory.text_only_channel_list.get_cdn_repos.empty?
    assert advisory.text_only_channel_list.cdn_repo_list.empty?
  end

  test "omits deleted channels" do
    list = TextOnlyChannelList.find(9)
    channel = Channel.find_by_name!('jb-middleware')

    assert_equal [channel], list.get_channels

    # channel disappears from result once deleted
    channel.destroy

    assert_equal [], list.get_channels
  end

  test "omits deleted repos" do
    list = TextOnlyChannelList.find(17)
    repos = CdnRepo.find([59, 156]).to_a

    assert_equal repos.sort_by(&:id), list.get_cdn_repos.sort_by(&:id)

    # disappears from result once deleted
    repos[0].destroy

    assert_equal [repos[1]], list.get_cdn_repos
  end
end
