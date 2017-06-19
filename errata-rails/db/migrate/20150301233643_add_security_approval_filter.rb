class AddSecurityApprovalFilter < ActiveRecord::Migration
  # Adds a system filter for issues "Awaiting Security Approval".
  #
  # Note that I want the filter to have the same ID in every
  # environment, so its URL can be documented and handed out.
  # However, we didn't explicitly reserve any range of IDs for system
  # filters.
  #
  # At this point, ID=6 happens to be available in production and in
  # fixtures, so use it.
  def up
    # The security approval is an added criteria on top of the default
    # criteria.  (Mainly to limit to active errata.)
    default_filter_params = SystemErrataFilter.default.filter_params
    filter_params = default_filter_params.merge(
      'security_approval' => ['requested'])

    filter = SystemErrataFilter.new(
      :name => 'Awaiting Security Approval',
      :filter_params => filter_params,
      :display_order => 7000)
    filter.id = 6
    filter.save!
  end

  def down
    SystemErrataFilter.find(6).destroy
  end
end
