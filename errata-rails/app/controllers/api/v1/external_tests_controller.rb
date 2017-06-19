module Api
  module V1
    # :api-category: Tests
    class ExternalTestsController < ApiController

      #
      # Get details of external tests.
      #
      # :api-url: /api/v1/external_tests?filter[key]=value
      # :api-method: GET
      # :api-response-example: file:test/data/api/v1/external_tests/index_filter[errata_id]=18905.json
      #
      # Returns an array of external tests under the top-level key 'data'. The array can be
      # empty depending on the filters used. The meaning of each attribute within the external
      # test objects is documented under [GET /api/v1/external_tests/{id}].
      #
      # This is a [paginated API].
      #
      # ##### Filtering
      #
      # The list of tests can be filtered by applying `filter[key]=value` as a
      # query parameter. All keys under `attributes`, including `id`, can
      # be used as a filter. Additionally, some attributes of related objects can be used
      # for filtering:
      #
      # * `errata_id` - numeric ID of an advisory
      # * `brew_build_id` - numeric ID of a brew build
      #
      # For example:
      #
      # * `/api/v1/external_tests?filter[errata_id]=14509&filter[test_type]=covscan`
      #   returns external tests with type "covscan" for advisory 14509
      #
      def _api_doc_index
      end


      #
      # Get details of an external test.
      #
      # :api-url: /api/v1/external_tests/{id}
      # :api-method: GET
      # :api-response-example: file:test/data/api/v1/external_tests/show_83.json
      #
      # External tests are test runs invoked externally from Errata Tool.
      #
      # Parameters are returned under the top-level key `data` which is further
      # divided into `attributes`. Data contains the following keys:
      #
      # * `id`: unique identifier of the test
      # * `type`: "external_tests" string to indicate the type of resource
      #
      # ##### Attributes
      #
      # * `active`: active or not. A test which is not active has generally been obsoleted by
      #             a newer test (see also `superseded_by` relationship). (boolean)
      # * `created_at`: time when the test was created (ISO8601 timestamp)
      # * `updated_at`: time when the test was most recently updated (ISO8601 timestamp)
      # * `status`: one of: PASSED, WAIVED, INELIGIBLE, FAILED, PENDING (string)
      # * `test_type`: a brief unique identifying name for the type of this test.
      #                See notes below. (string)
      # * `external_id`: unique ID of the test in the external test system (integer)
      # * `external_message`: a message from the external test system (string)
      # * `external_status`: status of the test in the external test system (string)
      #
      # ###### Test types
      #
      # Generally, there will be a separate `test_type` value for each separate external
      # test system.
      #
      # The semantics of each attribute beginning with `external` may differ between
      # each test type. Consumers should be cautious, and consult the documentation of the
      # relevant external test system if possible.
      #
      # Some test systems may provide multiple related types of test results.
      # In these cases, related types are grouped under a common namespace delimited by '/'.
      # `external_id` may not be unique between tests of related types, however such tests
      # may supersede each other.
      #
      # The test types currently defined include:
      #
      # * `covscan` - Covscan / Coverity Scan service
      # * `ccat` - CDN Content Availability Testing
      # * `ccat/manual` - CDN Content Availability Testing (manually triggered)
      #
      # Callers should assume that new test types may be introduced at any time.  A caller
      # making decisions based on the external test results should ignore unknown test types.
      #
      # ##### Relationships
      #
      # These related resources are returned under `data.relationships`:
      #
      # * `errata`: Advisory covered by this test.
      #             Includes `id`, `fulladvisory`, and `errata_type`.
      # * `brew_build`: The brew build covered by this test.
      #                 Includes `id` and `nvr`.
      #                 Only included for certain test types.
      # * `superseded_by`: If present, this is a later test of the same type or a related type
      #                    which has obsoleted this result.
      #                    Includes `id`, `status` and `test_type`.
      #
      def _api_doc_show
      end

      def resource_class
        ExternalTestRun
      end

      def resource_query
        resource_class.joins(:external_test_type)
      end

      def render_params
        { :order_by => 'id ASC' }
      end

      def valid_filter_attributes
        super + %w[external_test_types]
      end

      def apply_filter_transformations
        return if @query_filter.blank?

        if (test_type_name = @query_filter.delete('test_type'))
          @query_filter['external_test_types'] = {:name => test_type_name}
        end
      end
    end
  end
end
