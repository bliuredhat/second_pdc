# :api-category: Legacy
class Noauth::CveController < Noauth::ControllerBase
  include AdvisoryFinder
  before_filter :find_errata, :only => [:show]
  respond_to :json

  #
  # Fetch a list of CVEs, grouped by advisory.
  #
  # :api-url: /cve/list.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "817":{
  #     "issue_date":"2003-04-08T00:00:00Z",
  #     "update_date":"2003-04-09T00:00:00Z",
  #     "cve":[
  #       "CVE-2003-0196",
  #       "CVE-2003-0201"
  #     ],
  #     "advisory":"RHSA-2003:137",
  #     "actual_ship_date":"2003-04-08T00:00:00Z"
  #   },
  #   "12329":{
  #     "issue_date":"2011-12-14T18:48:11Z",
  #     "update_date":"2011-12-14T18:48:10Z",
  #     "cve":[
  #       "CVE-2011-4539"
  #     ],
  #     "advisory":"RHSA-2011:1819",
  #     "actual_ship_date":"2011-12-14T19:02:25Z"
  #   }
  # }
  # ````
  def list
    if params[:id]
      ids = params[:id].split(',')
    else
      ids = ErrataService.new.list_cve_errata
    end

    advisories = Errata.where(:id => ids).includes(:content)
    info = advisories.inject({}) do |h,e|
      h[e.id] = {
        :cve => e.all_cves,
        :advisory => e.advisory_name,
        :issue_date => e.issue_date,
        :update_date => e.update_date,
        :actual_ship_date => e.actual_ship_date
      }
      h
    end
    respond_with(info)
  end

  #
  # Fetch CVE information for a specific advisory.
  #
  # :api-url: /cve/show/{errata_id}.json
  # :api-method: GET
  #
  # Example response:
  #
  # ```` JavaScript
  # {
  #   "cve":[
  #     "CVE-2003-0196",
  #     "CVE-2003-0201"
  #   ],
  #   "advisory":"RHSA-2003:137"
  # }
  # ````
  def show
    respond_with({:cve => @errata.all_cves,
                   :advisory => @errata.advisory_name})
  end
end
