# Mixin concern to allow finding by name or id based on parameter type.
# If id is numeric, or a string that matches a number, use find.
# Otherwise, use find_by_name!
#
# TODO: Maybe use included() to test if object responds_to find_by_name!
module FindByIdOrName
  extend ActiveSupport::Concern
  module ClassMethods
    def find_by_id_or_name(value_or_values, name_attr="name")
      expect_list = value_or_values.is_a?(Array)

      values = if value_or_values
                 Array.wrap(value_or_values).map(&:to_s).uniq
               else
                 # we need non empty array, so that we can tell which one is
                 # not found
                 [nil]
               end

      name_attr = "id" if values.first =~ /^[0-9]+$/
      results = where(name_attr => values)
      results = results.limit(1) unless expect_list

      found_values = results.map { |r| r[name_attr].to_s }
      missing = values - found_values

      # not use any?, because it will return true for array with [nil]
      unless missing.empty?
        raise ActiveRecord::RecordNotFound,
              "Couldn't find #{name} with #{name_attr} '#{missing.join(', ')}'"
      end

      expect_list ? results : results.first
    end
  end
end
