#
# Want consistent method names for short name and long name even
# though different attributes are used depending on the model.
# Doing it this way to avoid major schema changes.
#
# This is just for rendering. To update you need to know what the
# attributes really are. Might need some more logic here later.
#
# Most things use name/description but product uses short_name/name
#
# Might need more logic in here later to support other models.
# Currently just focussing on Product and ProductVersion for the new
# management UI.
#
module CanonicalNames
  extend ActiveSupport::Concern

  #
  # Shorter name, eg RHEL or RHEL-5
  #
  def canonical_short_name
    if respond_to?(:short_name)
      short_name
    elsif respond_to?(:name)
      name
    elsif respond_to?(:title)
      title
    end
  end

  #
  # Longer name, eg "Red Hat Enterprise Linux" or "Red Hat Enterprise Linux 5"
  #
  def canonical_long_name
    if respond_to?(:verbose_name)
      verbose_name
    elsif respond_to?(:short_name)
      name
    elsif respond_to?(:description)
      description
    else
      ''
    end
  end

  #
  # Is the object currently active?
  # (Experimental. Not too sure about this one since the meaning varies I think)
  #
  def canonical_is_active?
    if respond_to?(:isactive?)
      isactive?
    elsif respond_to?(:active?)
      active?
    elsif respond_to?(:enabled?)
      enabled?
    else
      true # I guess..
    end
  end

end
