module SharedApi::Paginate
  extend ActiveSupport::Concern

  included do
    # Subclasses may call this to declare pagination options.
    #
    # Accepts options:
    #  :default    - default size of a page when unspecified in request
    #  :max        - maximum permitted size of a page
    #
    def self.paginate(args)
      [:max, :default].each do |key|
        value = args.delete(key)

        if value
          define_method("page_size_#{key}") do
            value
          end
        end
      end

      if args.present?
        raise ArgumentError, "Unknown arguments to paginate: #{args.inspect}"
      end
    end
    private_class_method :paginate

    paginate :default => 100, :max => 1000
  end

  # Returns a page of +data+, paginated according to parameters and defaults, or
  # raises if there is a problem relating to pagination.
  #
  # +data+ must be a will_paginate supported type, e.g. an array or
  # ActiveRecord::Relation.
  def apply_pagination(data)
    page   = params.fetch(:page, {})
    number = integer! page.fetch(:number, 1), 'page[number]'
    size   = integer! page.fetch(:size, page_size_default), 'page[size]'

    if size > page_size_max
      raise DetailedArgumentError.new(
              :codes => :bad_page,
              'page[size]' => "Requested #{size} items per page, but maximum of #{page_size_max} is permitted.")
    end

    # paginate has some range checking already, piggy back for validation
    begin
      data.paginate(:page => number, :per_page => size)
    rescue RangeError => e
      raise DetailedArgumentError.new(
              :codes => :bad_page,
              :page => e.message)
    end
  end

  private

  def integer!(value, label)
    value_i = value.to_i
    if value_i.to_s != value.to_s
      raise DetailedArgumentError.new(
              :codes => :invalid_type,
              label  => "must be an integer")
    end
    value_i
  end
end
