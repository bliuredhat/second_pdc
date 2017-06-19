# :api-category: Builds
class Api::V1::BuildController < ApplicationController
  respond_to :json

  before_filter :find_build

  #
  # Get Brew build details.
  #
  # :api-url: /api/v1/build/{id_or_nvr}
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/build/show_rhel-server-docker-7.0-22.json
  #
  # The IDs of brew builds and brew files are equal to those used by
  # brew itself, and hence may be used with brew's API.
  #
  # The type of a file is either "rpm" for an RPM, or the name of an
  # archive type as reported by brew's API (based on file extension).
  #
  # If Errata Tool doesn't know about the requested build, it will ask
  # brew before responding, which may be slow.
  #
  # A build which has not yet completed may not be queried.
  #
  def show
  end

  private

  def find_build
    id = params[:id]
    @build = BrewBuild.make_from_rpc_without_mandatory_srpm(id, :fail_on_missing => false)
    redirect_to_error!("no such build #{id}", :not_found) unless @build
  end
end
