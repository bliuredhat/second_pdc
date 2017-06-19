class AutomaticAdvisoryController < ApplicationController
  include ReplaceHtml

  verify :method => :post,
  :only => :create_quarterly_update

  before_filter :set_show_ineligible_packages

  def new_qu
    new_advisory is_pdc: false
  end

  def new_qu_pdc
    new_advisory is_pdc: true
  end

  def create_quarterly_update
    pkgs = params['pkgs'] || {}
    package_ids = pkgs.reject { |key,val| val == '0'}.keys
    if package_ids.empty?
      flash_message :error, "You need to select at least one package!"

      is_pdc = params[:type].match(/^Pdc/)
      action = is_pdc ? :new_qu_pdc : :new_qu

      action_with_params = params.slice(:product, :release, :type, :security_impact)
                                 .merge(action: action)
      return redirect_to action_with_params
    end

    advisory = AutomaticallyFiledAdvisory.new(package_ids, params)
    if advisory.save
      flash_message :alert, "Please edit the advisory to set the topic, CVE names, and other fields as required" if advisory.errata.is_security?
      redirect_to :action => :view, :controller => :errata, :id => advisory.errata
    else
      msg = ["ERROR: Unable to create an advisory; you will need to use the standard form."]
      msg << "Please e-mail #{Settings.errata_help_email} with the following errors:"
      advisory.errors.each { |attr, err| msg << "#{attr} #{err}"}
      redirect_to_error! msg.join("<br/>").html_safe
    end
  end

  def qu_for_product
    product = Product.find_by_id(params[:product][:id])
    is_pdc = params[:is_pdc].in?(%w(true 1))

    releases = current_releases_for_product(product, is_pdc: is_pdc).sort_by(&:name)

    if releases.any?
      @release = releases.first
      # Normally there would be some releases (I presume)..
      bugs_for_release = BugsForRelease.new(@release)
      pkgs                   = bugs_for_release.eligible_bugs_by_package
      @packages_not_eligible = bugs_for_release.ineligible_bugs_by_package
    else
      # ..but if there aren't, need to do this otherwise exceptions are thrown silently
      # to the user, (since this is an ajax update), and the new form gets messed up.
      # (Am seeing this in my dev environment, perhaps due to old data).
      pkgs                   = {}
      @packages_not_eligible = {}
    end

    js = package_list_js(:qu_for_product_spinner, :object => pkgs, :locals => { :release => releases.first })
    js += js_for_template(:packages_for_release_list, 'packages_for_release_list', :object => releases)
    render_js js
  end

  def packages_for_release
    release = Release.find(params[:release][:id])
    bugs_for_release = BugsForRelease.new(release)
    @packages_not_eligible = bugs_for_release.ineligible_bugs_by_package
    render_js package_list_js(:packages_for_release_spinner,
                              :object => bugs_for_release.eligible_bugs_by_package,
                              :locals => { :release => release })
  end

  private

  def new_advisory(is_pdc:)
    product_releases = Hash.new { |hash, key| hash[key] = Set.new }

    extra_javascript %w[new_advisory help_modal]

    [QuarterlyUpdate, FastTrack].each do |release_type|
      releases = current_releases(release_type, is_pdc: is_pdc)

      releases.each do |release|
        product_releases[release.product] << release if release.product

        # NOTE: legacy advisory relations have two ways to map product to release
        #   products --<- release     (release.product)
        #   products --<- product_versions --<- releases
        unless is_pdc
          release.release_versions
                 .each { |rv| product_releases[rv.product] << release }
        end
      end
    end

    # In case we get redirected back from create_quarterly_update
    specified_product = params[:product] ? Product.find_by_id(params[:product][:id]) : nil
    specified_release = params[:release] ? Release.find_by_id(params[:release][:id]) : nil

    @products = product_releases.keys.sort_by(&:name)

    @product =
      (specified_product if specified_product && @products.include?(specified_product)) ||
      @products.find { |x| x.short_name == 'RHEL' } ||
      @products.first

    @releases = product_releases[@product].sort_by(&:name)

    if @releases.any?
      @release =
        (specified_release if specified_release && @releases.include?(specified_release)) ||
        @releases.first

      bugs_for_release = BugsForRelease.new(@release)
      # Actually these contain bugs grouped by package..
      @packages              = bugs_for_release.eligible_bugs_by_package
      @packages_not_eligible = bugs_for_release.ineligible_bugs_by_package
    else
      # Prevent exceptions in unlikely case there are no releases found
      @packages              = {}
      @packages_not_eligible = {}
    end

    @errata_types = is_pdc ? ErrataType.pdc : ErrataType.legacy
    @is_pdc = is_pdc

    render :new
  end

  # The entire #package_list container needs to be replaced including
  # the top node. The partial is rendered on load of the document,
  # therefore we either create additional partials or use the
  # 'replaceWith' method in jQuery
  #
  def package_list_js(spinnerid_to_hide, render_args)
    js = js_for_template(:package_list, 'package_list', render_args, 'replaceWith')
    js += js_hide spinnerid_to_hide
    js
  end

  def set_show_ineligible_packages
    @show_ineligible_packages = params.fetch('show_ineligible_packages', 0).to_bool
  end

  # returns current and enabled releases for a ReleaseType
  # like QuarterlyUpdate, FastTrack etc
  def current_releases(release_type, is_pdc:)
    if is_pdc
      release_type.current.enabled.pdc
    else
      release_type.current.enabled.legacy
    end
  end

  # returns releases for the given product
  def current_releases_for_product(product, is_pdc:)
    # TODO: Make a named scope for this.
    # Also note this appears to mostly duplicate the `product_releases = ...` code in new :/

    [QuarterlyUpdate, FastTrack].flat_map do |release_type|
      releases = current_releases(release_type, is_pdc: is_pdc)
      if is_pdc
        releases.where(product_id: product)
      else
        releases
          .joins(:product_versions)
          .where(%(
            releases.product_id = ?
            or product_versions.product_id = ?
          ), product, product)
      end
    end.uniq
  end

end
