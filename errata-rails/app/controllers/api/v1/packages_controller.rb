module Api
  module V1
    # :api-category: Packages
    class PackagesController < ApiController

      before_filter :ensure_query_present, :only => [:index]

      # HACK: to get documentation generated

      #
      # Get details of all packages ordered by name.
      #
      # :api-url: /api/v1/packages?filter[key]=value
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/packages/libcgroup.json
      #
      # Returns an array of packages under the top-level key 'data'. The array can be
      # empty depending on the filters used. The meaning of each attribute of a package
      # is documented under [GET /api/v1/packages/{id}]
      #
      # *NOTE*: /api/v1/packages without `?filter[key]=value` will result in an error (400) as
      # the api does not support listing all packages.
      #
      # This is a [paginated API].
      #
      # ##### Filtering
      # The list of packages can be filtered by applying `filter[key]=value` as a
      # query parameter. All keys under `attributes` of a package including `id` can
      # be used as a filter. e.g.
      #
      # * `/api/v1/packages?filter[name]=libcgroup` finds the package with name equal to libcgroup
      # * `/api/v1/packages?filter[id]=939` finds the package with `id` 939
      #
      # *NOTE*: The last one may appear to be same as `/api/v1/packages/939` except
      # that `filter[id]=939` always returns *200* and an empty array if no package
      # could be found that has the id - 939 whereas `/api/v1/packages/939` returns
      # a *404* and error object if the package doesn't exist.
      #
      def _api_doc_index
      end

      #
      #
      # Get details of a package by its id.
      #
      # :api-url: /api/v1/packages/{id}
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/packages/939.json
      #
      # Parameters are returned under the top-level key `data` which is further
      # divided into `attributes`. Data contains the following keys
      #
      # * `id`: unique identifier of the package
      # * `type`: "packages" string to indicate the type of resource
      #
      # ##### Attributes
      #
      # * `name`: Name of the package (string)
      #
      # ##### Relationships
      #
      # Following relationships are returned under `data.relationships`. Each
      # relationship has an `id` which is a unique identifier of that resource
      #
      # * `devel_owner`: Object that represents Package owner; contains `id` and `realname`
      # * `devel_responsibility`: Object that represents devel responsibility;
      #                           contains `id` and `name`
      # * `docs_responsibility`: Object that represents doc team; contains `id` and `name`
      # * `errata`: Array of current errata with. Each item in the array contains
      #             its `id`, `fulladvisory`, `errata_type`, `status`,
      #             and `actual_ship_date`
      # * `qe_owner`: Object that represents qe team; contains id and name
      # * `quality_responsibility`: Object that represents qe responsibility;
      #                            contains `id` and `realname`
      #
      def _api_doc_show
      end

      private

      def ensure_query_present
        if params[:filter].nil?
          raise DetailedArgumentError.new(
            :codes => :missing_query_param,
            :reason => "Must provide 'filter[key]=value' query parameter"
          )
        end
      end
    end # PackagesController
  end # V1
end # Api
