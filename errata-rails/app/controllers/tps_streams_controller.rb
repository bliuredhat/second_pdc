class TpsStreamsController < ApplicationController
  include CurrentUser, ReplaceHtml

  before_filter :admin_restricted, :only => :sync
  before_filter :set_index_nav, :only => :index

  verify :method => :post, :only => [:sync]

  def index
    set_page_title 'TPS streams'
    @is_admin = current_user_in_role?('admin')
    @tps_variants = TpsVariant.order('name')
    @tps_stream_types = TpsStreamType.order('name')
    @tps_streams = TpsStream.includes(:parent).all.sort_by(&:full_name)
  end

  def sync
    begin
      results = Tps::SyncTpsStreams.sync
      messages = ["TPS streams synced successfully."]
      results.each_pair do |klass,v|
        ['deleted', 'created'].each do |action|
          counter = v[action]
          next if counter <= 0
          klass_name_humanize = klass.name.underscore.humanize
          type = counter > 1 ? "#{klass_name_humanize.pluralize} are" : "#{klass_name_humanize} is"
          messages << "#{counter} #{type} #{action}."
        end
      end
      flash_message :notice, messages.join("\n")
    rescue SocketError, Net::HTTPServerException => e
      flash_message :error, "Failed to sync with TPS server. #{e.message}"
    end
    redirect_to :action => 'index'
  end

  def get_secondary_nav
    return [
            {:name => 'Running Jobs',
              :controller => :tps,
              :action => :running_jobs},
            {:name => 'Open Jobs',
              :controller => :tps,
              :action => :open_jobs},
            {:name => 'Failing Jobs',
              :controller => :tps,
              :action => :failing_jobs},
            {:name => 'TPS Streams',
              :controller => :tps_streams,
              :action => :index}
           ]
  end
end
