require 'error_handling/errata_exception'
require 'stringio'
require 'pp'
require 'uri'
require 'net/https'
require 'resolv'
require 'jbuilder'

#
# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
#
class ApplicationController < ActionController::Base
  include RequestLogging, UserAuthentication, ErrorHandling, AdvisoryFinder, SslRequirement

  # See http://rubydoc.info/gems/bartt-ssl_requirement/
  ssl_exceptions # none

  layout :gen_layout
  cache_sweeper :comment_sweeper

  # Startup actions
  # (authentication is not performed for signin actions or rpc requests)
  before_filter :clear_thread
  before_filter :security_headers
  before_filter :check_user_auth
  before_filter :readonly_restricted

  around_filter :embargo_check

  # Trying to fix problem with noauth controllers getting a stale
  # current_user because thread is reused by passenger. See Bug 92100.
  after_filter  :clear_thread

  protected

  def security_headers
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'sameorigin'
    response.headers['X-XSS-Protection'] = '1; mode=block'

    if request.ssl?
      response.headers['Strict-Transport-Security'] = "max-age=31536000; includeSubDomains"
    end
  end

  #
  # Convenient method to create or update objects from forms. To
  # customise what happens after the successful update/create, a block
  # can be given, e.g.
  #
  #   def create
  #     create_or_update do |obj|
  #       redirect_to(obj, :notice => 'Updated.'
  #     end
  #   end
  #
  def create_or_update(opts = {})
    raise 'Can only call for create or update!' unless ['create', 'update'].include?(action_name)
    klass = opts[:klass] || Kernel.const_get(controller_name.camelize.singularize)

    ivar_name = klass.to_s.underscore
    object_params = params[ivar_name]
    obj = klass.new(object_params) if 'create' == action_name
    obj ||= klass.find(params[:id])

    instance_variable_set("@#{ivar_name}", obj)
    obj.update_attributes(opts[:options])

    valid = obj.save if 'create' == action_name
    valid ||= obj.update_attributes(object_params)
    respond_to do |format|
      if valid
        format.html do
          msg = "#{klass} #{obj.try(:name)} successfully #{action_name}d"
          if block_given?
            yield obj
          else
            redirect_to(obj, :notice => msg)
          end
        end
        format.json { render :json => obj.to_json }
      else
        format.html { render :action => { 'create' => 'new', 'update' => 'edit'}[action_name] }
        format.json { render :json => {:errors => obj.errors}.to_json, :status => :unprocessable_entity  }
      end
    end
  end

  def embargo_check
    if User.current_user.can_see_embargoed?
      yield
    else
      Errata.with_unembargoed_scope { yield }
    end
  end

  def hash_to_string(hash)
    s = StringIO.new
    PP.pp(hash,s)
    s.rewind
    return  s.read
  end

  def flash_message(key, message)
    if flash[key]
      flash[key] += "<hr>#{message}".html_safe
    else
      flash[key] = message
    end
  end

  # (We don't ever fade now so :nofade should be obsolete. Todo: confirm and remove)
  def flash_notice_js(notice, opts={})
    if notice.present?
      notice = view_context.escape_javascript(notice)
      notice_type = opts[:type] || 'notice'
      nofade = opts[:nofade] || notice_type == :error
      "displayFlashNotice('#{notice_type}','#{notice.full_stop}', #{nofade});#{opts[:do_after]}"
    else
      'jQuery.noop();'
    end
  end

  # Like flash_message but using the new nicer styled element.
  def flash_notice_message(notice, opts={})
    render :js => flash_notice_js(notice, opts)
  end

  def update_flash_notice_message(msg, opts={})
    flash_notice_message(msg, opts)
  end

  # Utility method for redirecting back to the referrer, or a set redirect option if
  # referrer is not set.
  #
  # source - http://shanti.railsblog.com/how-to-redirect-users-back-in-rails
  #
  def redirect_back(redirect_opts = nil)
    redirect_opts ||= {:controller => :errata}
    request.env["HTTP_REFERER"] ? redirect_to(request.env["HTTP_REFERER"]) : redirect_to(redirect_opts)
  end

  def get_individual_errata_nav(errata = @errata)
    return [] unless errata

    # Saw an odd exception one time when calling this for a json request.
    # Non-html requests should not need a nav bar, so let's do this:
    return [] if request.format.try(:symbol) != :html

    individual_errata_nav = []

    # The new 'Summary' tab
    individual_errata_nav.concat [
                                  { :name => 'Summary',
                                    :controller => 'errata',
                                    :action => 'view',
                                    :id => errata.id},
                                  { :name => 'Details',
                                    :controller => 'errata',
                                    :action => 'details',
                                    :id => errata.id}]

    unless errata.text_only?
      individual_errata_nav << { :name => 'Builds',
        :controller => 'brew',
        :action => 'list_files',
        :id => errata.id}

      if errata.has_brew_files_requiring_meta?
        individual_errata_nav << { :name => 'Files',
          :controller => 'brew',
          :action => 'edit_file_meta',
          :id => errata.id}
      end

      if errata.requires_rpmdiff?
        individual_errata_nav << { :name => 'RPMDiff',
          :controller => 'rpmdiff',
          :action => 'list',
          :id => errata.id}
      end

      if errata.requires_abidiff?
        individual_errata_nav << { :name => 'ABI Diff',
          :controller => 'abidiff',
          :action => 'list',
          :id => errata.id}
      end

      errata.external_tests_required(ExternalTestType.toplevel).each do |test_type|
        test_type_name = test_type.name

        # Tab can be hidden based on certain criteria
        show_method = "use_#{test_type_name}?"
        if errata.respond_to?(show_method) && !errata.send(show_method)
          next
        end

        individual_errata_nav << {
          :name       => test_type.tab_name,
          :controller => 'external_tests',
          :action     => 'list',
          :id         => errata.id,
          :test_type  => test_type_name
        }
      end

      if errata.requires_tps? && errata.tps_run
        individual_errata_nav << { :name => 'TPS',
          :controller => 'tps',
          :action => 'errata_results',
          :id => errata.tps_run.id}
        if errata.has_distqa_jobs?
          individual_errata_nav << { :name => 'DistQA TPS',
            :controller => 'tps',
            :action => 'rhnqa_results',
            :id => errata.tps_run.id}
        end
      end

      unless errata.build_mappings.empty?
        individual_errata_nav << {
          :name => 'Content',
          :controller => 'errata',
          :action => 'content',
          :id => errata.id,
        }
      end

      if errata.has_docker?
        individual_errata_nav << {
          :name => 'Container',
          :controller => 'errata',
          :action => 'container',
          :id => errata.id,
        }
      end
    end

    individual_errata_nav << {
      :name => 'Docs',
      :controller => 'docs',
      :action => 'show',
      :id => errata.id
    }

    individual_errata_nav << { :name => 'Test Results',
      :controller => 'errata',
      :action => 'test_results',
      :id => errata.id}

    # huh? this seems very confusing..
    nav_links = Hash.new { |hash, key| hash[key] = {}}
    individual_errata_nav.each do |nav|
      nav_links[nav[:controller]][nav[:action]] = individual_errata_nav
    end
    nav_links['rpmdiff']['show'] = individual_errata_nav

    use_controller = params[:controller]
    use_action = params[:action]

    # hack so some of the other docs or rpmdiff actions appear under the right tab
    case use_controller
    when 'docs'
      use_action = 'show'
    when 'rpmdiff', 'external_tests'
      use_action = 'list'
    end

    #
    # So I want to use errata tabs when we are on a page
    # that isn't one of the tabs.. Need to do this:
    # (This is a confusing mess, fixme...)
    #
    # Sometimes that happens when are a doing an action that
    # is a post that will redirect to another action. So actually
    # it doesn't need a tabs menu anyhow, so why bother building
    # this. (Another fixme).
    #
    nav_links_for_controller = nav_links[use_controller]
    nav_links_for_controller ||= nav_links['errata'] # fallback if we are in a controller not mentioned so far
    nav_links_for_controller_action = nav_links_for_controller[use_action]
    nav_links_for_controller_action ||= nav_links_for_controller['view'] || nav_links['errata']['view'] # fallback...
    #
    # Do some work to pre-populate the selected one..
    # Warning, this kind of repeats stuff in set_index_nav
    # Also I'm still not sure why it builds a list of links
    # for each different controller/action...
    #
    return nav_links_for_controller_action.map do |link|
      if use_controller == link[:controller] && use_action == link[:action]
        link[:selected] = true
        # Will use this in page_title_helper
        @secondary_nav_selected_name = link[:name]
      end
      link
    end
  end
  helper_method :get_individual_errata_nav

  #
  # An easy way to get a user preference. Want to use it in views
  # also hence helper_method.
  # @user.preferences is a hash with (probably) symbols for keys.
  #
  def user_pref(pref, for_user=nil)
    user = for_user || @current_user || User.current_user
    user.preferences[pref] if user
  end
  helper_method :user_pref

  def get_secondary_nav
    return get_individual_errata_nav
  end

  def set_index_nav
    @secondary_nav = get_secondary_nav
    return if @secondary_nav.nil?

    # Selected tab has been set manually already, maybe in the controller
    return if @secondary_nav.any? { |n| n[:selected] }

    # Figure out which tab is current one
    selected = @secondary_nav.find { |nav_item|
      # Has current controller (if controller is specified)
      (nav_item[:controller].nil? || nav_item[:controller].to_s == params[:controller].to_s) &&
      (
        # Has current action...
        nav_item[:action].to_s == params[:action].to_s ||
        # or should also appear selected for the current action
        Array.wrap(nav_item[:also_selected_for]).map(&:to_s).include?(params[:action].to_s)
      ) &&
      # Has the same id (if one is specified)
      (nav_item[:id].nil? || nav_item[:id].to_s == params[:id].to_s)
    }

    if selected
      # This will apply the highlight class, see a/v/layout/main_layout
      selected[:selected] = true
      # This will be used in page_title_helper
      @secondary_nav_selected_name = selected[:name]
    end
  end

  def gen_layout
    if params[:nolayout] || request.xhr?
      # If the nolayout variable is present in the params array
      # (may be passed via get or post), or if it is an ajax request,
      # do not use a layout template
      nil
    else
      'main_layout'
    end
  end

  # Set the html head title
  # Defined here (as opposed to setting @page_title in the code)
  # to allow global formatting and such
  def set_page_title(title, opts={})
    @page_title = title
    @page_title_override = title if opts[:override]
    @_no_auto_title = true if opts[:no_auto_title]
  end

  #
  # before_filter for ubiquitous finding of objects by name or by id.
  # allows /turtle/19, /turtle/Ruby or /turtle?name='Ruby'
  #
  # See also:
  #   app/models/concerns/find_by_id_or_name
  #
  # Assumptions:
  #  controller name is same as class name; i.e. if params[:controller] == 'turtle'
  #  will look for class named 'Turtle' that responds to both find and find_by_name
  #
  #  If object found, instance variable will be set with same name as controller;
  #  i.e. using this in the turtle_controller will set a @turtle instance variable
  #
  def find_by_id_or_name(error_handler=nil)
    error_handler ||= lambda do |msg|
      logger.error "find_by_id_or_name #{msg}"
      return redirect_to_error!(msg)
    end

    unless params[:id] || params[:name]
      return error_handler.call("No id or name parameter given")
    end

    classname = params[:controller].camelize.singularize
    id = params[:id]
    id ||= params[:name]
    method = :find

    if id.blank?
      return error_handler.call("Empty id or name parameter given")
    end

    begin
      klass = Kernel.const_get(classname)
      if !id.match(/^[0-9]+$/)
        method = :find_by_name!
      end

      unless klass.respond_to?(method)
        return error_handler.call("#{classname} does not respond to #{method}")
      end
    rescue => e
      return error_handler.call("No such class name #{classname}")
    end

    begin
      obj = klass.send(method, id)
    rescue => e
      return error_handler.call(e.message)
    end

    instance_variable_set("@#{params[:controller].singularize}", obj)
    true
  end

  #
  # Same as the above but instead of using redirect_to_error!
  # just add a flash alert and go back.
  #
  def find_by_id_or_name_with_flash_alert
    find_by_id_or_name(lambda do |msg|
      flash_message :alert, msg
      redirect_back(:action=>:index)
    end)
  end

  def validate_urls(urls)
    url_errors = []
    urls.each do |url|
      begin 
        uri = URI.parse(url)
        request = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == "https"
          request.use_ssl = true 
          request.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request.open_timeout=4
        request.read_timeout=4
        resp = request.head(uri.path)
        next if resp.is_a? Net::HTTPOK
        
        url_errors << "#{url} - #{resp.code}: #{resp.class.to_s}"
      rescue Exception => e
        url_errors << "#{url} - #{e.message}"
      end
    end
    return url_errors
  end

  def extra_javascript(*javascripts)
    @extra_scripts ||= []
    @extra_scripts += javascripts.flatten
  end

  def extra_stylesheet(*stylesheets)
    @extra_styles ||= []
    @extra_styles += stylesheets.flatten
  end

  def respond_with_success(message, opts = {})
    location = opts[:location] || referrer
    jbuilder = opts[:jbuilder] || nil
    status = opts[:status] || :ok

    respond_to do |format|
      format.json do
        if jbuilder.present?
          render jbuilder, :status => status
        else
          render :json => {:notice => message}, :status => status
        end
      end
      format.html { redirect_to(location, :notice => message) }
    end
  end

  def render_json_error(format, error)
    format.json { render :json => { :error => error.message }.to_json, :status => :unprocessable_entity  }
  end

  # Use as around_filter to wrap an action in a transaction
  def with_transaction
    ActiveRecord::Base.transaction { yield }
  end

  def set_flash_message(type, messages)
    msg = Array.wrap(messages).join('<br/>')
    flash_message type, msg unless msg.empty?
  end

  def log_message(type, messages)
    msg = Array.wrap(messages).join("\n")
    Rails.logger.send(type, msg) unless msg.empty?
  end

  def referrer
    referrer_uri = request.env["HTTP_REFERER"]
    request_uri = request.env["REQUEST_URI"]

    # FIXME: will go back even if it is not in the same domain
    if referrer_uri.present? && referrer_uri != request_uri
      return referrer_uri
    end
    return {:action => :index}
  end

  def ajax_spinner
    extra_javascript %w[ajax_spinner]
    extra_stylesheet %w[ajax_spinner]
    @show_ajax_spinner = true
  end
end
