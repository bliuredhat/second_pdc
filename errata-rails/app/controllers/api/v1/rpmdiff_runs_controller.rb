module Api
  module V1
    # :api-category: RPMDiff Runs
    class RpmdiffRunsController < ApiController

      # HACK to get documentation generated

      #
      #
      # Get the details of an rpmdiff run by its id.
      #
      # :api-url: /api/v1/rpmdiff_runs/{id}
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/rpmdiff_runs/40893.json
      #
      # * `id`: unique identifier of the rpmdiff run
      # * `type`: "rpmdiff_runs" string to indicate the type of resource
      #
      # The meaning of the "overall_score" is documented under [GET /advisory/{id}/rpmdiff_runs.json]
      def _api_doc_show
      end

    end
  end  # V1
end  # Api
