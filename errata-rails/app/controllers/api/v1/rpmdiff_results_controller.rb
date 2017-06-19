module Api
  module V1
    # :api-category: RPMDiff Results
    class RpmdiffResultsController < ApiController

      # HACK to get documentation generated

      #
      #
      # Get the details of an rpmdiff result by its id.
      #
      # :api-url: /api/v1/rpmdiff_results/{id}
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/rpmdiff_results/3026610.json
      #
      # * `id`: unique identifier of the rpmdiff result
      # * `type`: "rpmdiff_results" string to indicate the type of resource
      #
      # The meaning of the "score" is documented under [GET /advisory/{id}/rpmdiff_runs.json]
      def _api_doc_show
      end

    end
  end  # V1
end  # Api
