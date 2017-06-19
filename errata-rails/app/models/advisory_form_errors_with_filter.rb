# This class is intended for usage with AdvisoryForm.
#
# It will filter out certain errors from full_messages which are not supposed to
# be displayed in the usual area on the pages for editing AdvisoryForm
# instances.
class AdvisoryFormErrorsWithFilter < ErrorsWithFilter

  # These errors can be displayed directly against form inputs.
  FORM_INPUT_ERROR_KEYS = [
    :package_owner_email,
    :manager_email,
    :assigned_to_email,
    :synopsis,
    :keywords,
    :crossref,
    :topic,
    :idsfixed,
    :description,
    :solution,
    :reference,
  ]

  def initialize(delegate)
    super(self.class.method(:accept?), delegate)
  end

  def self.accept?(key)
    !FORM_INPUT_ERROR_KEYS.include?(key)
  end
end
