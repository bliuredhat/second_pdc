class PushTarget < ActiveRecord::Base
  include FindByIdOrName

  validates_presence_of :name, :description, :push_type
  validates_uniqueness_of :name

  # Filter out ftp push target here, since
  # variant doesn't use ftp.
  # altsrc is pushing the same files as rhn now, so there is no
  # effect to limit files to push to altsrc. This may change
  # in the future if the altsrc push logic is changed.
  # Thus, limit the push targets to rhn and cdn only for now.
  scope :allowable_by_variant, where('push_type like ? or push_type like ?', "rhn%", "cdn%")

  default_scope order('is_internal asc, name desc')

  validate(:on => :create) do
    unless Push::Pub.is_valid_push_target? target_name
      errors.add(:name, "Invalid push target name #{target_name}. Only the following are currently configured: #{Push::Pub.valid_push_targets.join(', ')}")
    end
    unless PushJob.valid_push_types.include? push_type
      errors.add(:push_type, "Invalid push type #{push_type}; only #{PushJob.valid_push_types.join(', ')} valid")
    end
  end

  def target_name
    name.to_sym
  end

  def pub_target
    Push::Pub::pub_target(target_name)
  end

  def push_type
    read_attribute(:push_type).to_sym
  end

  def display_name
    push_type.to_s.camelize
  end

  # True if pub can push multiple errata in a single task with this push target.
  def supports_multipush?
    Settings.pub_use_multipush.include?(push_type)
  end
end
