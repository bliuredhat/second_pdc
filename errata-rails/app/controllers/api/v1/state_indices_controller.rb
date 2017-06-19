module Api
  module V1
    # :api-category: State_Indices
    class StateIndicesController < ApplicationController
      respond_to :json
      before_filter :find_errata
      #
      # Retrieve all advisory state_indices.
      #
      # :api-url: /api/v1/state_indices/{errata_id}
      # :api-method: GET
      # :api-response-example: file:test/data/api/v1/state_indices/show_advisory_10844.json
      #
      # Returns an array of state_indices for an advisory. These records contain
      # details about advisory state changes.
      #
      def show
        @state_indices = @errata.state_indices.reorder('created_at asc')

      end
    end
  end
end
