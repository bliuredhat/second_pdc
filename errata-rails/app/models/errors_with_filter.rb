# This class can be used to wrap an ActiveModel::Errors and filter out certain
# messages from full_messages.
#
# The purpose is to facilitate the usage of the dynamic_form gem's
# error_messages_for method (widely used in ET), while omitting certain messages
# expected to be displayed in other parts of the UI (e.g. next to form inputs).
class ErrorsWithFilter < SimpleDelegator

  # Create a new filtered errors object.
  #
  # +filter+ is a proc which will be passed an error key and should return true
  # if the error should be included in the result of full_messages.
  #
  # +delegate+ is the ActiveModel::Errors object to be filtered.
  def initialize(filter, delegate)
    @filter = filter
    super(delegate)
  end

  def full_messages
    map do |attribute, message|
      full_message(attribute, message) if @filter[attribute]
    end.compact
  end
end
