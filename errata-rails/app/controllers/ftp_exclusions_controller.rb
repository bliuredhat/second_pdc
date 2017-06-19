class FtpExclusionsController < ApplicationController
  # There is only readonly stuff here so I won't worry about restricting to admin users.
  # (The link to get here is in the product admin page though, so non-admin users probably
  # won't find this anyway).

  before_filter :set_secondary_nav_and_title

  def index
    redirect_to :action => :list_product_exclusions
  end

  def lookup_package_exclusions
    # (Let's make short url params)
    @product_match         = params[:p  ] || ''
    @product_version_match = params[:pv ] || ''
    @package_match         = params[:pkg] || ''
    @excluded_only         = params[:ex] == 'on'

    if @product_match.present? || @product_version_match.present? || @package_match.present?
      # Use ErrataBrewMapping to determine which combinations of package & product_version go together
      @results = ErrataBrewMapping.search_by_pkg_prod_ver_or_prod(@package_match, @product_version_match, @product_match)
    end
  end

  def list_product_exclusions
    @products = Product.active_products('short_name')
  end

  protected

  def set_secondary_nav_and_title
    set_page_title 'SRPM FTP Exclusions'
    @secondary_nav = [
      { :controller => :ftp_exclusions, :action => 'list_product_exclusions',   :name => 'All Product & Product Version FTP Exclusions' },
      { :controller => :ftp_exclusions, :action => 'lookup_package_exclusions', :name => 'Lookup FTP Exclusions by Package'             },
    ]
    # Probably should do this elsewhere..
    @secondary_nav.each { |link| link[:selected] = true if params[:action] == link[:action] }
  end
end
