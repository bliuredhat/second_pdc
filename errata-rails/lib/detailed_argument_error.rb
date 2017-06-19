# An ArgumentError which can retain specific errors for each argument.
class DetailedArgumentError < ArgumentError
  # An ActiveModel::Errors object.
  attr_reader :field_errors

  def initialize(errors = {})
    @field_errors = _to_activemodel_errors(errors)
    msg = @field_errors.full_messages.join(', ')
    super(msg)
  end

  def _to_activemodel_errors(errors)
    if errors.kind_of?(ActiveModel::Errors)
     return errors
    end

    out = ActiveModel::Errors.new(self)
    errors.each do |key,vals|
      # array or plain strings are accepted as the values
      Array.wrap(vals).each{|msg| out.add(key, msg.to_s)}
    end
    out
  end

  # Given an enumerable of [field, exception] pairs, attempts to merge all of the
  # exceptions into a new DetailedArgumentError and return it.
  #
  # For example, if a few different records failed validation and raised ActiveRecord::RecordInvalid,
  # the errors for the records can be merged, from:
  #
  #   [['a', record_a_exception], ['b', record_b_exception]]
  #
  # ...to an exception with errors:
  #
  #  {'a somefield' => ['is too short'], 'a otherfield' => ['must be unique'],
  #   'b somefield' => ['You do not have permission to set this field'], ...}
  #
  # If any exception cannot have field errors extracted, returns an arbitrary one
  # of the passed exceptions.
  def self.merge_errors(kv)
    hsh = HashList.new

    kv.each do |outer_key,exception|
      if !exception.respond_to?(:field_errors)
        # can't merge.  Just return an exception to be reraised.
        return exception
      end

      exception.field_errors.each do |inner_key, error|
        # don't uselessly double up the keys
        key = [outer_key, inner_key].map(&:to_s).reject(&:blank?).uniq.join(' ')
        hsh[key] << error
      end
    end

    return DetailedArgumentError.new(hsh)
  end

  # Needed for ActiveModel::Errors
  def self.human_attribute_name(attr, options={})
    attr
  end
end
