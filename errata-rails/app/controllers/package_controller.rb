require 'csv'

class PackageController < ApplicationController
  before_filter :set_index_nav
  before_filter :admin_restricted, :only => [:update_cyp, :create_ftp_exclusion, :delete_ftp_exclusion]
  before_filter :find_by_id_or_name_with_flash_alert, :only => [:show]
  verify :method => :post, :only => [:create_ftp_exclusion, :delete_ftp_exclusion]
  respond_to :json, :only => [:list]

  def index
    set_page_title "Search for Packages"
    return unless request.post?
    if params[:pkg] && params[:pkg][:name]
      name = params[:pkg][:name].strip
      pkg = Package.find_by_name(name)
      if pkg
        redirect_to :action => :show, :name => pkg.url_name
      else
        flash_message :alert, "No such package #{name}"
        redirect_to :action => :index
      end
    end
  end

  def ftp_exclusion
    conditions = []
    if params[:product]
      prod = Product.find_by_short_name(params[:product])
      conditions = ['ftp_exclusions.product_id = ?', prod]
    elsif params[:product_version]
      pv = ProductVersion.find_by_name(params[:product_version])
      conditions = ['ftp_exclusions.product_version_id = ?', pv]
    end
    @exclusions = FtpExclusion.paginate(:page => params[:page],
                                        :conditions => conditions,
                                        :include =>
                                        [:package, :product, :product_version],
                                        :order => 'errata_products.name, packages.name'
                                        )
  end

  def create_ftp_exclusion
    @ftp_exclusion = FtpExclusion.new(params[:ftp_exclusion])
    if @ftp_exclusion.save
      flash_message :notice, "FTP exclusion created!"
    else
      flash_message :error, "ERROR: Unable to create FTP exclusion: #{@ftp_exclusion.errors.full_messages}"
    end
    redirect_back # back to 'show/:package_name'
  end

  def delete_ftp_exclusion
    @ftp_exclusion = FtpExclusion.find(params[:ftp_exclusion_id])
    if @ftp_exclusion
      @ftp_exclusion.destroy
      flash_message :notice, "FTP exclusion removed!"
    else
      flash_message :error, "ERROR: FTP exclusion not found!"
    end
    redirect_back # back to 'show/:package_name'
  end

  def qe_team
    unless params[:id]
      redirect_to :action => :qe_team, :id => QualityResponsibility.find(:first, :order => 'name').url_name
      return
    end
    resp = QualityResponsibility.find_by_url_name(params[:id])
    @packages = resp.packages.find(:all, :conditions => 'id in (select package_id from released_packages)')
    @default_owner = resp.default_owner
    set_page_title "Packages for #{resp.name}"
  end

  def devel_team
    unless params[:id]
      redirect_to :action => :devel_team, :id => DevelResponsibility.find(:first, :order => 'name').url_name
      return
    end
    resp = DevelResponsibility.find_by_url_name(params[:id])
    @packages = resp.packages.find(:all, :conditions => 'id in (select package_id from released_packages)')
    set_page_title "Packages for #{resp.name}"
  end

  def devel_owner
    if params[:id]
      user = User.find_by_login_name(params[:id] + '@redhat.com')
      @items = Package.find(:all, :conditions => ['devel_owner_id = ?', user])
      @action = :show
      set_page_title "Packages owned by #{user.to_s}"
    else
      @items = User.find(:all,
                         :conditions => 'users.id in (select devel_owner_id from packages where packages.id in (select package_id from released_packages))',
                         :order => 'realname')
      @action = :devel_owner
      set_page_title "Devel owners"
    end
  end

  def show
    extra_javascript 'package_show'
    set_page_title "Package '#{@package.name}'", :override => true

    @current_errata = []
    @shipped_errata = []
    @unfiled_errata = []
    maps = @package.errata_brew_mappings.includes([:brew_build, :errata])
    pdc_maps = PdcErrataReleaseBuild.joins(:brew_build).where(brew_builds: {package_id: @package}).includes([:brew_build, :errata])

    maps.concat(pdc_maps)

    # We only require one map per build for each advisory
    # Ruby 1.8.7 doesn't support uniq with a block, which would be nicer
    maps = Hash[maps.map{|m| ["#{m.errata.id}_#{m.brew_build_id}", m]}].values

    maps.each do |m|
      next if m.errata.status == State::DROPPED_NO_SHIP
      @shipped_errata << m if m.errata.status == State::SHIPPED_LIVE
      @current_errata << m unless m.errata.status == State::SHIPPED_LIVE
    end
    @current_errata.sort! { |a,b| a.errata.id <=> b.errata.id}
    @shipped_errata.sort! { |a,b| b.errata.issue_date <=> a.errata.issue_date}

    @ftp_exclusions = FtpExclusion.for_package(@package)
    @allow_exclusion_edit = current_user.in_role?('admin')
  end

  def update_cyp
    cyp_content = Net::HTTP.get(URI.parse('http://southpark.englab.brq.redhat.com:8083/export/'))
    cyp = CSV.parse(cyp_content)
    cyp.shift if cyp.first[0] == 'component'

    set_page_title "Update CYP"
    @changes = []
    pkg_resp = { }
    qresp = { }
    cyp.each do |c|
      pkg_name = c[0]
      resp_name = c[4]
      resp_email = c[5]
      resp_name = 'Default' if resp_name == 'NONE'
      qresp[resp_name] = resp_email
      pkg = Package.find_by_name(pkg_name)
      if pkg
        unless pkg.quality_responsibility.name == resp_name
          pkg_resp[pkg] = resp_name
          @changes <<  "#{pkg_name} QA changed from #{pkg.quality_responsibility.name} to #{resp_name}"
        end
      else
        pkg_resp[pkg_name] = resp_name
        @changes << "New Package #{pkg_name} with qa group: #{resp_name}"
      end
    end

    return unless request.post?
    return if pkg_resp.empty?

    new_resp = qresp.keys.select {|k| !QualityResponsibility.exists?(['name = ?', k])}
    new_resp.each do |name|
      email = qresp[name]
      owner = User.find_by_login_name(email)
      unless owner
        owner = User.create(:login_name => email, :realname => name)
        owner.roles << Role.find_by_name('qa')
      end
      QualityResponsibility.create(:name => name, :default_owner => owner)
    end

    qresp.keys.each { |k| qresp[k] = QualityResponsibility.find_by_name(k)}
    pkg_resp.each_pair do |pkg, resp_name|
      pkg = Package.new(:name => pkg) if pkg.class == String
      pkg.quality_responsibility = qresp[resp_name]
      pkg.save
    end

    flash_message :notice, @changes.join("<br/>")
    redirect_to :action => :index
  end

  def list
    respond_to do |format|
      list = []
      if params[:name].present?
        name = params[:name]
        list = Package.select('name').where('name like ?', "%#{name}%").map(&:attributes)
      end
      format.json { render :json => list.to_json}
    end
  end

  protected

  def get_secondary_nav
    nav = []
    if ['index', 'show', 'devel_owner', 'update_cyp'].include?(params[:action])
      nav =  [
              { :name => 'Search', :controller => :package, :action => :index},
              { :name => 'By QE Team', :controller => :package, :action => :qe_team},
              { :name => 'By Devel Team', :controller => :package, :action => :devel_team},
              { :name => 'By Devel Owner', :controller => :package, :action => :devel_owner, :id => nil},
             ]
    elsif params[:action] == 'qe_team'
      nav << { :name => 'Back to Search', :controller => :package, :action => :index}
      QualityResponsibility.find(:all, :order => 'name').each do |r|
        nav << { :name => r.name, :controller => :package, :action => :qe_team, :id => r.url_name} if r.packages.size > 0
      end
    elsif params[:action] == 'devel_team'
      nav << { :name => 'Back to Search', :controller => :package, :action => :index}
      DevelResponsibility.find(:all, :order => 'name').each do |r|
        nav << { :name => r.name, :controller => :package, :action => :devel_team, :id => r.url_name}
      end
    end
    if current_user.in_role?('admin')
      nav << { :name => 'Update CYP Info', :controller => :package, :action => :update_cyp }
    end
    return nav
  end

end
