#
# Decided to move these out of the user model so they
# are easier to review and manage.
#
# See also:
#   app/controllers/concerns/user_authentication
#   app/controllers/concerns/current_user
#
module UserPermissions

  ROLE_PERMISSIONS = {
    :add_released_packages         => %w[ releng admin secalert ],
    :see_add_released_packages_tab => %w[ releng admin ],
    :remove_released_packages      => %w[ releng admin ],
    :approve_security              => %w[ secalert ],
    :create_async                  => %w[ createasync ],
    :create_autowaive_rule         => Settings.autowaive_create_roles,
    :edit_autowaive_rule           => Settings.autowaive_edit_roles,
    :manage_autowaive_rule         => Settings.autowaive_manage_roles,
    :manage_batches                => %w[ admin secalert pm releng ],
    :manage_cdn_repo_packages      => %w[ releng admin ],
    :request_buildroot_push        => %w[ admin qa releng ],
    :cancel_buildroot_push         => %w[ admin qa releng ],
    :ack_product_listings_mismatch => %w[ admin releng ],
  }

  ROLE_PERMISSIONS.each do |permission_type, permitted_roles|
    define_method("can_#{permission_type}?") do
      in_role?(*permitted_roles)
    end
  end

  #----------------------------------------------------

  def permitted?(permission_type, *args)
    can_method = "can_#{permission_type}?"
    raise "Invalid permission type #{permission_type}" unless respond_to?(can_method)
    send(can_method, *args)
  end

  #----------------------------------------------------

  def can_see_embargoed?
    !is_readonly?
  end

  def can_request_signatures?
    in_role?('qa', 'admin', 'secalert')
  end

  def can_reschedule_covscan?
    # Rescheduling a scan is somewhat restricted (as requested by ttomecek)
    in_role?('covscan-admin', 'secalert', 'admin', 'super-user')
  end

  def can_reschedule_errored_covscan?
    # If Covscan threw an error let's be more permissive about who can reschedule it
    can_reschedule_covscan? || in_role?('qa', 'devel', 'releng')
  end

  def can_waive_tps_job?
    in_role?('qa', 'admin', 'secalert')
  end

  def can_ack_rpmdiff_waiver?
    !is_readonly? && in_role?('qa', 'admin', 'secalert')
  end

  def can_approve_docs?
    in_role?('docs', 'admin', 'secalert')
  end

  def can_see_managed_errata?
    is_manager? && in_role?('management') && in_role?('qa', 'devel')
  end

  def can_sync_component_list?
    !is_readonly?
  end

  # ** Actually this is not authoritative, see admin_restricted in user_authentication.rb
  def can_edit_admin_objects?
    in_role?('admin', 'super-user', 'releng') # pm?
  end

  def can_edit_cpe?
    in_role?('secalert', 'admin', 'super-user')
  end

  def can_modify_cve?(errata=nil)
    in_role?('secalert') || is_kernel_developer? || (errata && errata.is_low_security?)
  end

  def can_create_multi_product_advisory?
    in_role?('secalert', 'admin', 'releng')
  end

  def can_disapprove_security?
    !is_readonly?
  end

  def can_request_security_approval?
    !is_readonly?
  end

end
