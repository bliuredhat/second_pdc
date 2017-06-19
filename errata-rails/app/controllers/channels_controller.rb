class ChannelsController < ApplicationController
  include ManageUICommon
  include DistRepo
  include ErrorHandling
  include SharedApi::SearchByNameLike

  respond_to :html, :json, :xml

  private

  def create_or_update_channel
    create_or_update_dist_repo(@product_version)
  end

  def attach_channel_to_variant
    attach_dist_repo_to_variant(@channel, @variant)
  end

  def detach_channel
    detach_dist_repo(@channel, @product_version)
  end

  def delete_channel
    delete_dist_repo(@channel)
  end
end
