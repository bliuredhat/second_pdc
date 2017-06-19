class RhtsController < ApplicationController
  def index
    @errata = Errata.find_by_advisory params[:errata_id]
    set_page_title "RHTS Runs for #{@errata.advisory_name} - #{@errata.synopsis}"
  end
end
