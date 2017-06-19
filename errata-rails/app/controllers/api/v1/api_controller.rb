module Api
  module V1
    class ApiController < ApplicationController
      include SharedApi::Paginate

      # allow child classes to change query
      attr_accessor :query_filter

      respond_to :json

      around_filter :with_validation_error_rendering
      before_filter :set_resource, :only => [:destroy, :show, :update]
      before_filter :create_filter, :apply_filter_transformations, :validate_filter,
                    :on => [:index]

      # GET /api/v1/{plural_resource_name}?filter[key]=value
      def index
        data = resource_query.where(@query_filter).order(render_params[:order_by])
        data = apply_pagination(data)
        resources_var = "@#{plural_resource_name}"
        instance_variable_set(resources_var, data)
        respond_with data
      end

      # GET /api/v1/{plural_resource_name}/:id
      def show
        respond_with get_resource
      end

      # POST /api/{plural_resource_name}
      def create
        set_resource(resource_class.new(resource_params))
        if ActiveRecord::Base.transaction { get_resource.save && after_create }
          render :show, :status => :created
        else
          respond_with_error get_resource.errors, :status => :unprocessable_entity
        end
      end

      # PUT /api/v1/{plural_resource_name}/1
      def update
        begin
          if ActiveRecord::Base.transaction { get_resource.update_attributes(update_params) && after_update }
            render :show
          else
            respond_with_error get_resource.errors, :status => :unprocessable_entity
          end
        rescue ActiveRecord::RecordInvalid => e
          respond_with_error e, :status => :unprocessable_entity
        end
      end

      # DELETE /api/v1/{plural_resource_name}/1
      def destroy
        begin
          if get_resource.destroy
            # Return 204 No Content on successful deletion
            head :no_content
          else
            respond_with_error get_resource.errors, :status => :unprocessable_entity
          end
        rescue ActiveRecord::RecordInvalid => e
          respond_with_error e, :status => :unprocessable_entity
        end
      end

      private

      # Use callbacks to share common setup or constraints between actions.
      def set_resource(resource = nil)
        resource ||= resource_class.find(params[:id])
        instance_variable_set("@#{resource_name}", resource)
      end

      # Returns the resource from the created instance variable
      # @return [Object]
      def get_resource
        instance_variable_get("@#{resource_name}")
      end

      # The resource class based on the controller
      # @return [Class]
      def resource_class
        @resource_class ||= resource_name.classify.constantize
      end

      # Top-level object to query for resources.
      # Override in subclasses.
      def resource_query
        resource_class
      end

      # The singular name for the resource class based on the controller
      # @return [String]
      def resource_name
        @resource_name ||= controller_name.singularize
      end

      # The pluralized name for the resource class based on the controller
      # @return [String]
      def plural_resource_name
        @plural_resource_name ||= resource_name.pluralize
      end

      # Returns the allowed parameters for searching
      # Override this method in each API controller
      # to permit additional parameters to search on
      # @return [Hash]
      def render_params
        { :order_by => 'LOWER(name) ASC' }
      end

      # Returns the allowed parameters for rendering
      # Override this method in each API controller
      # to permit additional parameters to search on
      # @return [Hash]
      def query_params
        {}
      end

      # Only allow a trusted parameter "white list" through.
      # If a single resource is loaded for #create,
      # then the controller for the resource must implement
      # the method "#{resource_name}_params" to limit permitted
      # parameters for the individual model.
      def resource_params
        @resource_params ||= send("#{resource_name}_params")
      end

      # White-listed parameters for #update. By default, this
      # is the same as for #create. The controller for the
      # resource may implement this method to return a
      # different set of parameters.
      def update_params
        resource_params
      end

      # Called after successful resource create. Override
      # this method to perform post-create processing.
      #
      # TODO: Consider making this work like filters
      def after_create
        true
      end

      # Called after successful resource update. Override
      # this method to perform post-update processing.
      #
      # TODO: Consider making this work like filters
      def after_update
        true
      end

      # filters

      # Initialises @query_filter based on the query path of the resource url
      # Performs transformation of 'true' or 'false' to boolean
      def create_filter
        @query_filter = params[:filter]
        return if @query_filter.nil?

        # transform string bool to actual boolean
        # for attributes that are not string type
        @query_filter.each do |k, v|
          if resource_class.columns_hash[k].try(:type) != :string
            @query_filter[k] = v == 'true' if v.in? %w(false true)
          end
        end
      end

      # override to apply transformation of @query_filter
      def apply_filter_transformations
      end

      # validates that the filter used in a query is valid
      def validate_filter
        ensure_filter_only_attributes
        ensure_no_unsupported_filters
      end

      # raise a DetailedAttributeError if filter params are not attributes of
      # the resource_class.
      def ensure_filter_only_attributes
        return if @query_filter.nil?

        filtered_attrs = @query_filter.keys
        invalid_attrs = filtered_attrs - valid_filter_attributes

        if invalid_attrs.present?
          logger.info 'Received unexpected params: %p' % [invalid_attrs]
          raise DetailedArgumentError.new(
            :codes => :invalid_filter,
            :params => invalid_attrs
          )
        end
      end

      # Raises  DetailedAttributeError if filter params contain any attribute
      # set in query_params[:unsupported]
      def ensure_no_unsupported_filters
        return if @query_filter.nil?

        unsupported_params = Array.wrap(query_params[:unsupported]).compact
        return if unsupported_params.empty?

        unsupported_attrs = unsupported_params.map(&:to_s) & @query_filter.keys

        if unsupported_attrs.present?
          logger.info 'Received unsupported params: %p' % [unsupported_attrs]
          raise DetailedArgumentError.new(
            :codes => :unsupported_filter,
            :params => unsupported_attrs
          )
        end
      end

      # Returns a list of all the valid top-level attribute names for filtering.
      # Intended to be overridden in subclasses.
      def valid_filter_attributes
        resource_class.attribute_names
      end

    end # ApiController
  end # V1
end # Api
