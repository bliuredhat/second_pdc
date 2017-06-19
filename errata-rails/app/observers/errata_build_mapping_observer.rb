# Bsae class for observers on ErrataBrewMapping.
class ErrataBuildMappingObserver < ActiveRecord::Observer
  # Returns true if the mapping was obsoleted.
  # The result is only valid if called during after_commit.
  def obsoleted?(mapping)
    changed = mapping.previous_changes
    return false unless changed.include?('current')

    (was_current,is_current) = changed['current']
    was_current==1 && is_current==0
  end

  # Returns true if this is a new mapping.
  # The result is only valid if called during after_commit.
  def new_record?(mapping)
    id_change = mapping.previous_changes['id']
    return id_change && id_change.first.nil?
  end
end
