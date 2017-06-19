module Api
  module V1
    # :api-category: Releases
    class ReleasesController < ApiController

      # This API needs a relatively large page size.  The reason is that the API
      # was initially published without pagination.  The default page size would
      # break compatibility with existing clients processing all releases at
      # once.
      #
      # By setting the default page size greater than the number of releases
      # present at the time the API was published, existing clients can continue
      # to behave as though the API is not paginated, at least until the amount
      # of available data grows to larger than this number.
      paginate :default => 600

      private

      def apply_filter_transformations
        return if @query_filter.nil?

        # we render isactive as is_active
        if @query_filter.include? :is_active
          @query_filter[:isactive] = @query_filter.delete(:is_active)
        end
      end

      def query_params
        { :unsupported => :blocker_flags }
      end

      # HACK to get documentation generated
      public

      #
      # Get details of all releases ordered by name.
      #
      # :api-url: /api/v1/releases
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/releases/index.json
      #
      # Returns an array of releases under the top-level key 'data'. The meaning
      # of each attribute of a Release is documented under
      # [GET /api/v1/releases/{id}]
      #
      # This is a [paginated API].
      #
      # ##### Filtering
      #
      # Releases can be filtered by applying `filter[key]=value` as a query
      # parameter. All `attributes` except *blocker_flags* of an release
      # (including `id`) can be used as a filter.
      # e.g.
      #
      # * `/api/v1/releases?filter[is_active]=true` finds all active releases
      # * `/api/v1/releases?filter[enabled]=true&filter[is_active]=true` finds
      # all release that are enabled and active
      #
      # * `/api/v1/releases?filter[name]=RHS-3.0.z` finds the release with name equal to RHS-3.0.z
      # * `/api/v1/releases?filter[id]=10` finds the release with `id` 10
      #
      # *NOTE*: The last one may appear to be same as `/api/v1/releases/10` except
      # that `filter[id]=10` always returns *200* and an empty array if no release
      # could be found that has the id - 10 whereas `/api/v1/releases/10` returns
      # a *404* and error object if the release doesn't exist.
      #
      #
      def _api_doc_index
      end

      #
      # Get the details of a release by its id.
      #
      # :api-url: /api/v1/releases/{id}
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/releases/21.json
      #
      # Parameters are returned under the top-level key `data` which is further
      # divided into `attributes` and `relationships`. Data contains the
      # following keys
      #
      # * `id`: unique identifier of the arch
      # * `type`: "releases" string to indicate the type of resource
      #
      #
      # ##### Attributes
      #
      # * `id`: unique identifier of the release
      # * `name`: Name of the release (string)
      # * `description`: Description of the release (string)
      # * `allow_pkg_dupes`: (boolean)
      # * `type`:  Release type (boolean)
      # * `ship_date`: (date)
      # * `enabled`: Release enabled or not (boolean)
      # * `is_active`:  active or inactive (boolean)
      # * `is_async`:  (boolean)
      # * `is_deferred`: (boolean)
      # * `allow_shadow`: (boolean)
      # * `allow_blocker`: (boolean)
      # * `allow_exception`: (boolean)
      # * `blocker_flags`: Array of blocker flags associated with the release
      #
      # ##### Relationships
      #
      # Following relationships are returned under `data.relationships`. Each
      # relationship has an `id` which is a unique identifier of that resource
      #
      # * `brew_tags`: Array of brew-tags with. Each item in the array contains
      #                its id and name
      # * `product_versions`: Array of product version associated with the release
      #                       Each product version has an id, and a name
      #
      def _api_doc_show
      end

    end
  end   #V1
end   #Api
