# :api-category: Pushing Advisories
class Api::V1::ErratumTextOnlyController < ApplicationController
  respond_to :json

  before_filter :find_errata
  before_filter :ensure_text_only

  READONLY_ACTIONS = [:channels_index, :repos_index]

  around_filter :with_transaction,                :except => READONLY_ACTIONS
  around_filter :with_validation_error_rendering, :except => READONLY_ACTIONS

  verify :method => :put,                         :except => READONLY_ACTIONS

  [:channels, :repos].each do |type|
    before_filter :"find_available_#{type}", :only => [:"#{type}_index", :"#{type}_update"]
    before_filter :"find_active_#{type}",    :only => [:"#{type}_index", :"#{type}_update"]
  end

  #
  # Get all available text-only RHN channels for an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/text_only_channels
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/erratum_text_only/channels/put_channel_1.json
  #
  # Responds with an array of channels for this advisory, along with an `enabled` property.
  # When `enabled` is true, the channel will be used for this advisory.
  #
  # This API is only applicable to text-only advisories.
  #
  def channels_index
  end

  #
  # Enable or disable text-only RHN channels for an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/text_only_channels
  # :api-method: PUT
  #
  # Input may be a single object or an array of objects specifying the
  # text-only channels to be enabled or disabled.  The configuration
  # of any channels omitted from the request will not be modified.
  #
  # Each object should contain a true or false `enabled` property to
  # set whether the channel will be used for this advisory, and a
  # `channel` property containing the ID or name of the channel, as in
  # the following examples:
  #
  # ```` JavaScript
  # // enable one channel
  # {"enabled":true,"channel":1124}
  #
  # // disable two channels
  # [{"enabled":false,"channel":1124},{"enabled":false,"channel":"rhel-x86_64-workstation-supplementary-7"}]
  # ````
  #
  # Responds with the updated text-only channel configuration, using
  # the same format as [GET /api/v1/erratum/{id}/text_only_channels].
  #
  # This API is only applicable to text-only advisories.
  #
  def channels_update
    do_update :dist_type => :channel, :dist_class => Channel, :setter => :set_channels_by_id
  end

  #
  # Get all available text-only CDN repos for an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/text_only_repos
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/erratum_text_only/repos/put_repo_1.json
  #
  # The usage and response format is the same as [GET
  # /api/v1/erratum/{id}/text_only_channels], using repos instead of
  # channels.
  #
  def repos_index
  end

  #
  # Enable or disable text-only CDN repos for an advisory.
  #
  # :api-url: /api/v1/erratum/{id}/text_only_repos
  # :api-method: PUT
  #
  # The usage and response format is the same as for [PUT
  # /api/v1/erratum/{id}/text_only_channels], using repos instead of
  # channels, as in the following requests:
  #
  # ```` JavaScript
  # // enable one repo
  # {"enabled":true,"repo":1824}
  #
  # // disable two repos
  # [{"enabled":false,"repo":1824},{"enabled":false,"repo":"rhel-5-server-rh-common-rpms__5Server__i386"}]
  # ````
  #
  def repos_update
    do_update :dist_type => :repo, :dist_class => CdnRepo, :setter => :set_cdn_repos_by_id
  end

  private

  def do_update(opts)
    dist_type = opts[:dist_type]
    dist_class = opts[:dist_class]

    # We accept an array of objects (which will end up in _json) or a
    # single object (which ends up merged into params).
    input = if params.include?('_json')
      params['_json'] || []
    else
      [params]
    end

    # Start with the current set, then add to/remove from it
    want = @active_dists.to_set

    input.each do |x|
      id_or_name = x[dist_type.to_s] || raise(DetailedArgumentError.new(dist_type => 'missing id or name'))
      dist = dist_class.find_by_id_or_name(id_or_name)

      enabled = x['enabled']
      # protect users against passing in "true" or "false" strings without realizing
      if enabled != true && enabled != false
        raise DetailedArgumentError.new("#{id_or_name} enabled" => "expected boolean, got #{enabled.class}")
      end

      if enabled
        unless @available_dists.include?(dist)
          raise DetailedArgumentError.new("#{dist_type} #{id_or_name}" => 'is not available for this advisory')
        end
        want << dist
      else
        want.delete(dist)
      end
    end

    list = @errata.text_only_channel_list
    list.send(opts[:setter], want.map(&:id))
    list.save!

    self.send("find_active_#{dist_type}s")
    render '_channel_or_repo_list', :locals => {:dist_type => dist_type}
  end

  def ensure_text_only
    unless @errata.text_only?
      redirect_to_error!("#{@errata.advisory_name} is not a text-only advisory", :unprocessable_entity)
    end
  end

  # finders for active/available channels/repos.
  # available: channel/repo is applicable for this advisory
  # active: channel/repo is set to be used for this advisory

  def find_available_channels
    find_available(:channels)
  end

  def find_available_repos
    find_available(:repos)
  end

  def find_active_channels
    find_active(:channels)
  end

  def find_active_repos
    # cdn_repos rather than repos due to lack of consistent method naming
    find_active(:cdn_repos)
  end

  def find_available(type)
    @available_dists = @errata.available_product_versions.map(&:"active_#{type}").flatten.uniq
  end

  def find_active(type)
    @active_dists = @errata.text_only_channel_list.send("get_#{type}")
  end
end
