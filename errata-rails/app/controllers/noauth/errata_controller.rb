# :api-category: Legacy
class Noauth::ErrataController < Noauth::ControllerBase
  include AdvisoryFinder
  verify :method => :get
  before_filter :find_errata, :except => :system_version

  #
  # Fetch a list of blocking errata for an errata.
  #
  # :api-url: /errata/blocking_errata_for/{errata_id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #   "2015:0940"
  # ]
  # ````
  def blocking_errata_for
    blockers = @errata.blocking_errata.collect { |e| e.shortadvisory }
    respond_to do |format|
      format.text { render :text => blockers.join(',') }
      format.json { render :json => blockers.to_json }
    end
  end

  #
  # Fetch a list of depending errata for an errata.
  #
  # :api-url: /errata/depending_errata_for/{errata_id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #   "2015:0988"
  # ]
  # ````
  def depending_errata_for
    blockers = @errata.dependent_errata.collect { |e| e.shortadvisory }
    respond_to do |format|
      format.text { render :text => blockers.join(',') }
      format.json { render :json => blockers.to_json }
    end
  end

  #
  # Fetch a list of channel packages belonging to an errata.
  #
  # :api-url: /errata/get_channel_packages/{errata_id}.json
  # :api-method: GET
  #
  # The list of channel packages can be narrowed by applying channel=[channel_name] as a query parameter.
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "rhel-x86_64-hpc-node-7":[
  #     "/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7_1/data/signed/fd431d51/i686/nspr-4.10.8-1.el7_1.i686.rpm",
  #     "/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7_1/data/signed/fd431d51/i686/nspr-debuginfo-4.10.8-1.el7_1.i686.rpm"
  #   ]
  # }
  # ````
  def get_channel_packages
    @channel_files = {}
    if params[:channel]
      channel = Channel.find_by_name(params[:channel])
      @channel_files = Push::Rhn.get_packages_by_errata(@errata, channel) if channel
    else
      @channel_files = Push::Rhn.get_packages_by_errata(@errata)
    end
    render_channel_files
  end

  #
  # Fetch a list of released channel packages for an errata.
  #
  # :api-url: /errata/get_released_channel_packages/{errata_id}.json
  # :api-method: GET
  #
  # The list of released channel packages can be narrowed by applying channel=[channel_name] as a query parameter.
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "rhel-x86_64-hpc-node-7":[
  #     "/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7_1/data/signed/fd431d51/i686/nspr-devel-4.10.8-1.el7_1.i686.rpm",
  #     "/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7_1/data/signed/fd431d51/i686/nspr-debuginfo-4.10.8-1.el7_1.i686.rpm"
  #   ]
  # }
  # ````
  def get_released_channel_packages
    @channel_files = {}
    if params[:channel]
      channel = Channel.find_by_name(params[:channel])
      @channel_files = Push::Rhn.get_released_packages_by_errata(@errata, channel) if channel
    else
      @channel_files = Push::Rhn.get_released_packages_by_errata(@errata)
    end
    render_channel_files
  end

  #
  # Fetch a list of pulp packages for an errata.
  #
  # :api-url: /errata/get_pulp_packages/{errata_id}.json
  # :api-method: GET
  #
  # The list of pulp packages can be narrowed by applying repo=[repository_name] as a query parameter.
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "jb-eap-7_DOT_0-for-rhel-7-server-rpms__7Server__x86_64":[
  #     "/mnt/redhat/brewroot/packages/eap7-activemq-artemis/1.0.0/5.redhat_2.1.ep7.el7/noarch/eap7-activemq-artemis-1.0.0-5.redhat_2.1.ep7.el7.noarch.rpm",
  #     "/mnt/redhat/brewroot/packages/eap7-activemq-artemis/1.0.0/5.redhat_2.1.ep7.el7/noarch/eap7-artemis-amqp-protocol-1.0.0-5.redhat_2.1.ep7.el7.noarch.rpm"
  #   ],
  #   "jb-eap-7_DOT_0-for-rhel-7-server-source-rpms__7Server__x86_64":[
  #     "/mnt/redhat/brewroot/packages/eap7-activemq-artemis/1.0.0/5.redhat_2.1.ep7.el7/src/eap7-activemq-artemis-1.0.0-5.redhat_2.1.ep7.el7.src.rpm",
  #     "/mnt/redhat/brewroot/packages/eap7-antlr/2.7.7/32.redhat_5.1.ep7.el7/src/eap7-antlr-2.7.7-32.redhat_5.1.ep7.el7.src.rpm"
  #   ]
  # }
  # ````
  def get_pulp_packages
    @repo_files = {}
    if params[:repo]
      repo = CdnRepo.find_by_name(params[:repo])
      @repo_files = Push::Cdn.get_packages_by_errata(@errata, repo) if repo
    else
      @repo_files = Push::Cdn.get_packages_by_errata(@errata)
    end
    render_repo_files
  end

  #
  # Fetch a list of released pulp packages for an errata.
  #
  # :api-url: /errata/get_released_pulp_packages/{errata_id}.json
  # :api-method: GET
  #
  # The list of released pulp packages can be narrowed by applying repo={repository_name} as a query parameter.
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "rhel-7-desktop-optional-rpms__7Client__x86_64":[
  #     "/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7_1/data/signed/fd431d51/i686/nspr-devel-4.10.8-1.el7_1.i686.rpm",
  #     "/mnt/redhat/brewroot/packages/nspr/4.10.8/1.el7_1/data/signed/fd431d51/i686/nspr-devel-4.10.8-1.el7_1.i686.rpm"
  #   ]
  # }
  # ````
  def get_released_pulp_packages
    @repo_files = {}
    if params[:repo]
      repo = CdnRepo.find_by_name params[:repo]
      @repo_files = Push::Cdn.get_released_packages_by_errata(@errata, repo) if repo
    else
      @repo_files = Push::Cdn.get_released_packages_by_errata(@errata)
    end
    render_repo_files
  end

  #
  # Fetch a list of released packages for an errata.
  #
  # :api-url: /errata/get_released_packages/{errata_id}.json?version={variant_name}&arch={arch_name}
  # :api-method: GET
  #
  # Name of arch and variant are required as parameters to query to get the list of released packages for an errata
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #   "/mnt/redhat/brewroot/packages/flash-plugin/10.2.159.1/1.el5/data/signed/37017186/i386/flash-plugin-10.2.159.1-1.el5.i386.rpm"
  # ]
  # ````
  def get_released_packages
    want_src = params[:want_src]
    variant = Variant.find_by_name(params[:version])
    arch = Arch.find_by_name(params[:arch])

    return redirect_to_error!("Can't find arch '#{params[:arch]}'!", :bad_request) unless arch
    return redirect_to_error!("Can't find variant '#{params[:version]}'!", :bad_request) unless variant

    versions = Variant.find(:all,
                            :conditions =>[ 'product_id = ? and rhel_variant_id = ?',
                                            @errata.product,
                                            variant.rhel_variant])
    files = Set.new
    @errata.errata_brew_mappings.for_rpms.each do |m|
      conditions = { :current => 1,
        :version_id => versions,
        :product_version_id => m.product_version,
        :package_id => m.package,
        :arch_id => arch}
      released = ReleasedPackage.find(:all,
                                      :conditions => conditions,
                                      :include => [:brew_rpm])
      next if released.empty?
      released.each do |r|
        if want_src.blank?
          files << r.full_path unless r.brew_rpm.is_srpm?
        else
          files << r.full_path if r.brew_rpm.is_srpm?
        end
      end
    end
    @files = files.to_a

    respond_to do |format|
      format.xml  { render :layout => false }
      format.text { render :text => @files.join("\n") + "\n" }
      format.json { render :layout => false, :json => @files.to_json}
    end
  end

  #
  # Fetch the currently installed version of Errata Tool.
  #
  # (You can also fetch this with an html or text request.)
  #
  # :api-url: /system_version.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # "3.12.3-0"
  # ````
  #
  def system_version
    respond_to do |format|
      format.json { render :json => SystemVersion::VERSION }
      format.text { render :text => SystemVersion::VERSION }
      format.html { render :text => SystemVersion::VERSION }
    end
  end

  #
  # Similar to contents of tps.txt but just for a single advisory.
  # See Bug 889013.
  #
  def get_tps_txt
    render :text => (@errata.tps_run.try(:tps_txt_output, :no_save_channel=>true) || ''), :content_type => 'text/plain'
  end

  protected
  def render_channel_files
    render_files(@channel_files, "noauth/errata/get_channel_packages")
  end

  def render_repo_files
    render_files(@repo_files, "noauth/errata/get_pulp_packages")
  end

  def render_files(file_list, template)
    respond_to do |format|
      format.xml  { render template, :layout => false, formats => [:xml]}
      format.text do
        text = []
        file_list.each_pair do |c, files|
          text << [c, files.to_a].join(',')
        end
        render :text => text.join("\n") + "\n"
      end
      format.json do
        render :layout => false,
        :json => file_list.to_json
      end
    end
  end
end
