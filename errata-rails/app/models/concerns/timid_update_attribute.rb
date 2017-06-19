module TimidUpdateAttribute
  #
  # Only update if it's not the same.
  # (A hack that can be used update an attribute in a callbacks
  # without triggering an infinite callback loop).
  #
  # Using this in product_version model to update a couple of
  # derived fields in after_save.
  #
  # (NB: In Rails 3.1 or higher we can just use update_column instead
  # which doesn't trigger callbacks instead of update_attribute).
  #
  def timid_update_attribute(attribute, new_value)
    current_value = self.send(attribute)
    self.update_attribute(attribute, new_value) if current_value != new_value
  end
end
