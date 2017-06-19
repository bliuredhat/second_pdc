module Api
  module V1
    # :api-category: Arches
    class ArchesController < ApiController

      # HACK to get documentation generated

      #
      # Get details of all arches ordered by name.
      #
      # :api-url: /api/v1/arches
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/arches/index.json
      #
      # Returns an array of arches under the top-level key 'data'. The array can be
      # empty depending on the filters used. The meaning of each attribute of
      # an Arch is documented under [GET /api/v1/arches/{id}]
      #
      # This is a [paginated API].
      #
      # ##### Filtering
      # The list of arches can be filtered by applying `filter[key]=value` as a
      # query parameter. All keys under `attributes` of an Arch including `id` can
      # be used as a filter. e.g.
      #
      # * `/api/v1/arches?filter[active]=true` finds all active arches
      # * `/api/v1/arches?filter[name]=amd64` finds the arch with name equal to amd64
      # * `/api/v1/arches?filter[id]=10` finds the arch with `id` 10
      #
      # *NOTE*: The last one may appear to be same as `/api/v1/arches/10` except
      # that `filter[id]=10` always returns *200* and an empty array if no arch
      # could be found that has the id - 10 whereas `/api/v1/arches/10` returns
      # a *404* and error object if the arch doesn't exist.
      #
      # Multiple filters can also be applied. e.g.
      #
      # * `/api/v1/arches?filter[active]=true&filter[name]=amd64` the arch name
      #    amd64 and is active. If no such Arch exists the data will be an empty
      #    array - `[]`.
      #
      def _api_doc_index
      end

      #
      #
      # Get the details of an arch by its id.
      #
      # :api-url: /api/v1/arches/{id}
      # :api-method: GET
      # :api-response-example: file:publican_docs/Developer_Guide/api_examples/arches/21.json
      #
      # Parameters are returned under the top-level key `data` which is further
      # divided into `attributes`. Data contains the following keys
      #
      # * `id`: unique identifier of the arch
      # * `type`: "arches" string to indicate the type of resource
      #
      # ##### Attributes
      #
      # * `name`: Name of the arch (string)
      # * `active`: active or not (boolean)
      #
      def _api_doc_show
      end

    end
  end  # V1
end  # Api
