class CdnReposController < ApplicationController
  include ManageUICommon
  include DistRepo
  include ErrorHandling
  include SharedApi::SearchByNameLike

  require 'jbuilder'
  respond_to :html, :json

  alias_method :find_cdn_repo, :find_dist_repo

  before_filter :find_cdn_repo, :only => [ :search_packages, :create_package_mapping, :delete_package_mapping, :package_tags ]
  skip_before_filter :find_parent, :only => [ :search_packages, :create_package_mapping, :delete_package_mapping, :package_tags, :add_package_tag, :remove_package_tag ]

  verify :method => :post, :only => [ :create_package_mapping, :delete_package_mapping, :add_package_tag, :remove_package_tag ]

  # This is for autocomplete of package names (excludes
  # packages that are already assigned to this repository)
  def search_packages
    respond_to do |format|
      list = []
      if params[:name].present?
        name = params[:name]
        list = Package.select('name').where(
          'name LIKE ? AND id NOT IN (SELECT package_id FROM cdn_repo_packages WHERE cdn_repo_id = ?)',
          "%#{name}%", @cdn_repo.id
        ).map(&:attributes)
      end
      format.json { render :json => list.to_json }
    end
  end

  def create_package_mapping
    @package_name = params[:package][:name]
    if @package_name.blank?
      flash_message :error, "ERROR: Package name must be specified"
      return redirect_to_packages_tab
    end

    package = Package.make_from_name(@package_name)

    mapping = CdnRepoPackage.new(:cdn_repo_id => @cdn_repo.id, :package => package)
    if mapping.save
      flash_message :notice, "Package '#{package.name}' is now mapped to repository '#{@cdn_repo.name}'"
    else
      flash_message :error, "ERROR: Unable to create package mapping: #{mapping.errors.full_messages}"
    end
    redirect_to_packages_tab
  end

  def delete_package_mapping
    @mapping = @cdn_repo.cdn_repo_packages.where(:package_id => params[:package_id]).first

    if @mapping.nil?
      flash_message :error, "ERROR: Package is not associated with repository"
    elsif !@mapping.destroy
      flash_message :error, @mapping.errors.full_messages.join('<br>')
    else
      flash_message :notice, "Package mapping has been removed"
    end
    redirect_to_packages_tab
  end

  def package_tags
    @package = Package.find(params[:package_id])
    @mapping = @package.cdn_repo_packages.where(:cdn_repo_id => params[:id]).first
    if @mapping.nil?
      flash_message :error, "ERROR: Package is not associated with repository"
      return redirect_to_packages_tab
    end

    @tags = @mapping.cdn_repo_package_tags
    set_page_title "Tags for '#{@package.name}'"
  end

  def add_package_tag
    mapping = CdnRepoPackage.find(params[:cdn_repo_package_id])
    if mapping.nil?
      flash_message :error, "ERROR: Package is not associated with repository"
      return redirect_to_packages_tab
    end

    tag = mapping.cdn_repo_package_tags.new(:tag_template => params[:tag_template], :variant_id => params[:variant_id])
    if tag.save
      flash_message :notice, ERB::Util::html_escape("Tag template '#{params[:tag_template]}' has been added")
    else
      flash_message :error, "ERROR: Unable to create tag template: #{tag.errors.full_messages}"
    end
    redirect_to :back
  end

  def remove_package_tag
    tag = CdnRepoPackageTag.find(params[:cdn_repo_package_tag_id])
    if tag.nil?
      flash_message :error, "ERROR: Tag not found"
      return redirect_to_packages_tab
    end

    tag.destroy
    flash_message :notice, ERB::Util::html_escape("Tag template '#{tag.tag_template}' has been removed")
    redirect_to :back
  end

  private

  def create_or_update_cdn_repo
    create_or_update_dist_repo(@parent)
  end

  def attach_cdn_repo_to_variant
    attach_dist_repo_to_variant(@cdn_repo, @variant)
  end

  def detach_cdn_repo
    detach_dist_repo(@cdn_repo, @parent)
  end

  def delete_cdn_repo
    # just for backward compatible. Should use detach/unlink
    # to unlink a cdn repo
    return detach if @variant && @cdn_repo.variant != @variant
    delete_dist_repo(@cdn_repo)
  end

  def redirect_to_packages_tab
    if request.referer
      redirect_to request.referer + "#packages_tab"
    else
      redirect_to variant_cdn_repo_path(@cdn_repo.variant, @cdn_repo, :anchor => "packages_tab")
    end
  end
end
