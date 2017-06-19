class TextOnlyChannelList < ActiveRecord::Base
  belongs_to :errata

  def set_channels_by_id(ids)
    if ids.nil?
      self.channel_list = ''
    else
      self.channel_list = Channel.find(ids).map { |c| c.name }.join(',')
    end
  end

  def get_channels
    self.channel_list.split(',').map { |n| Channel.find_by_name(n) }.compact
  end

  def set_cdn_repos_by_id(ids)
    if ids.nil?
      self.cdn_repo_list = ''
    else
      self.cdn_repo_list = CdnRepo.find(ids).map { |repo| repo.id}.join(',')
    end
  end

  def get_cdn_repos
    self.cdn_repo_list.split(',').map { |id| CdnRepo.find_by_id(id) }.compact
  end

  def get_all_channel_and_cdn_repos
    get_channels + get_cdn_repos
  end
end
