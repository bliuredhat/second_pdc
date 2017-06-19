# :api-category: Legacy
class RhelReleasesController < ApplicationController
  before_filter :admin_restricted
  before_filter :find_rhel_release,  :except => [:index, :new, :create]
  before_filter :find_all_rhel_releases, :except => :show
  respond_to :html, :json

  #
  # Fetch a list of RHEL releases.
  #
  # :api-url: /rhel_releases.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # [
  #  {
  #    "rhel_release": {
  #      "id":1,
  #      "name":"RHEL-2.1",
  #      "description":"Red Hat Advanced Server 2.1",
  #      "exclude_ftp_debuginfo":false
  #    }
  #  },
  #  {
  #    "rhel_release": {
  #      "id":2,
  #      "name":"RHEL-3",
  #      "description":"Red Hat Enterprise Linux 3",
  #      "exclude_ftp_debuginfo":false
  #    }
  #  }
  # ]
  # ````
  def index
    set_page_title 'RHEL Version Administration'
    respond_with(@rhel_releases)
  end

  #
  # Fetch the details of single RHEL release.
  #
  # :api-url: /rhel_release/{id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "rhel_release": {
  #     "id":1,
  #     "name":"RHEL-2.1",
  #     "description":"Red Hat Advanced Server 2.1",
  #     "exclude_ftp_debuginfo":false
  #   }
  # }
  # ````
  def show
    @rhel_release = RhelRelease.find(params[:id])
    respond_with(@rhel_release)
  end

  # Show a form to create a new RHEL release
  def new
    set_page_title 'Add new RHEL version'
    @rhel_release = RhelRelease.new
  end

  # Show a form to edit a RHEL release
  def edit
    set_page_title 'Edit RHEL version'
  end

  # Save a new RHEL release
  def create
    create_or_update
  end

  # Update an existing RHEL release
  def update
    create_or_update
  end

  # Delete a RHEL release
  def destroy
    # Would probably hit some foreign key exceptions if trying to delete,
    # but let's be sensible and prevent deleting RHEL releases that are in use.
    if @rhel_release.delete_ok?
      @rhel_release.destroy
      to_index :notice=>"RHEL version '#{@rhel_release.name}' removed"
    else
      to_index :error=>"Can't delete RHEL version '#{@rhel_release.name}'"
    end
  end

  protected #------------------------------

  def find_rhel_release
    @rhel_release = RhelRelease.find(params[:id])
  end

  def find_all_rhel_releases
    @rhel_releases = RhelRelease.by_name
  end

  def to_index(flash_hash={})
    redirect_to rhel_releases_path, :flash=>flash_hash
  end
end
