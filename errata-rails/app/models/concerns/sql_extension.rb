module SqlExtension
  extend ActiveSupport::Concern

  module ClassMethods
    def regex_where(params)
      if !params.is_a?(Hash)
        raise ArgumentError, "regex_where requires a hash as argument."
      end

      if sql_adapter =~ /^mysql/
        regex_symbol = 'REGEXP'
      # This is not tested so I think better to comment it out
      # elsif sql_adapter =~ /^PostgreSQL/
      #   regex_symbol = '~'
      else
        raise NotImplementedError, "regex_where is only supported for Mysql currently."
      end

      result = self.scoped

      params.each do |param|
        (field, regex_pattern) = get_field_and_value(param)
        result = result.where("#{field} #{regex_symbol} ?", regex_pattern)
      end

      return result
    end

    def sql_adapter
      ActiveRecord::Base.configurations[Rails.env]['adapter']
    end

    private

    def get_field_and_value(param)
      field = param[0].to_s
      fvalue = param[1]

      if !fvalue
        raise ArgumentError, "Field value can't be nil."
      elsif fvalue.is_a?(Hash)
        # Concat the field to table.column
        field = [field, fvalue.keys[0]].join('.')
        fvalue = fvalue.values[0]
      end

      return field, fvalue.to_s
    end
  end
end
