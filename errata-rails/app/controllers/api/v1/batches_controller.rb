# :api-category: Batches
class Api::V1::BatchesController < Api::V1::ApiController

  before_filter :batch_admin_restricted, :only => [:create, :update]

  private

  # Whitelisted parameters
  def batch_params
    params.slice(:name, :release_id, :release_name, :description, :release_date, :is_active, :is_locked)
  end

  public

  #
  # Get details of all batches ordered by name.
  #
  # :api-url: /api/v1/batches
  # :api-method: GET
  # :api-response-example: file:publican_docs/Developer_Guide/api_examples/batches/index.json
  #
  # Returns an array of advisory batches under the top-level key 'data'.
  # The array may be empty depending on the filters used. The meaning of each
  # attribute is documented under [GET /api/v1/batches/{id}]
  #
  # This is a [paginated API].
  #
  # ##### Filtering
  # The list of batches can be filtered by applying `filter[key]=value` as a
  # query parameter. All keys under `attributes` of a Batch including `id` can
  # be used as a filter.
  #
  def _api_doc_index
  end

  #
  # Get the details of a batch by its id.
  #
  # :api-url: /api/v1/batches/{id}
  # :api-method: GET
  # :api-response-example: file:publican_docs/Developer_Guide/api_examples/batches/2.json
  #
  # Parameters are returned under the top-level key `data` which is further
  # divided into `attributes`. Data contains the following keys
  #
  # * `id`: unique identifier of the batch
  # * `type`: "batches" string to indicate the type of resource
  #
  # ##### Attributes
  #
  # * `name`: Name of the batch (string)
  # * `is_active`: Active or not (boolean)
  # * `is_locked`: Whether the batch is locked (boolean)
  # * `description`: Batch description (string)
  # * `release_date`: Release date for batch (YYYY-MM-DD)
  #
  def _api_doc_show
  end

  #
  # Create a new batch.
  #
  # :api-url: /api/v1/batches
  # :api-method: POST
  # :api-request-example: file:publican_docs/Developer_Guide/api_examples/batches/create.json
  #
  # The response format on success is the same as for [GET /api/v1/batches/{id}].
  #
  # ##### Attributes
  #
  # The following attributes may be specified. A unique `name` must
  # be included, as well as a release (using either `release_id` or
  # `release_name`).
  #
  # * `name`: Name of the batch (string)
  # * `release_id`: ID of release (integer)
  # * `release_name`: Name of release (string)
  # * `is_active`: Active or not (boolean, default true)
  # * `is_locked`: Whether the batch is locked (boolean, default false)
  # * `description`: Batch description (string)
  # * `release_date`: Release date for batch (YYYY-MM-DD)
  #
  def _api_doc_create
  end

  #
  # Update attributes for an existing batch.
  #
  # :api-url: /api/v1/batches/{id}
  # :api-method: PUT
  #
  # The response format on success is the same as for [GET /api/v1/batches/{id}].
  #
  # Any of the attributes listed for [POST /api/v1/batches/{id}] may be
  # specified in the request. The release may only be changed if there
  # are no errata associated with the batch.
  #
  def _api_doc_update
  end

end
