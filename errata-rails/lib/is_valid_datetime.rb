module IsValidDatetime
  PATTERN = /^\d{4}-([A-Za-z]{3}|\d{2})-\d{1,2}$/
  #
  # Rails silently converts badly formated dates to nil, which passes
  # validations because the nil is allowed by the model. So use this
  # to do some date validations in ErrataController.
  #
  def is_valid_datetime(datestring)
    datestring = datestring.to_s.strip
    datestring.match(PATTERN) && DateTime.parse(datestring)
  rescue ArgumentError
    nil
  end

end
