module OrgChart
  # Synchronizes OrgChart user/group data into ET.
  #
  # * Assigns users/groups to orgchart based on name (for unambiguous matches only).
  # * Creates groups in ET when groups are created in orgchart.
  # * Updates group name, manager and parent.
  # * Updates user group membership.
  #
  class SyncJob
    def perform
      assign_groups
      assign_users

      ActiveRecord::Base.transaction do
        # transaction because update_groups updates some data left
        # unfilled during create_groups
        create_groups
        update_groups
      end

      update_users

      return
    end

    def self.enqueue_once
      Delayed::Job.enqueue_once self.new, 4, 5.seconds.from_now
    end

    def rerun?
      true
    end

    def next_run_time
      13.hours.from_now
    end

    private

    # Look up unassigned objects of the given type and attempt to assign them to orgchart objects
    # (setting orgchart_id).
    def assign_by_name(type, args = {})
      et_by_name = self.send("unassigned_#{type}s_by_name")
      oc_by_name = self.send("oc_#{type}s_by_name")

      et_by_name.each do |name,et_objects|
        next unless et_object = expect_single(et_objects, "ET #{type} named #{name}")

        oc_name = name
        oc_name = args[:et_name_to_oc_name].call(oc_name) if args[:et_name_to_oc_name]

        candidates = oc_by_name[oc_name] || []
        next unless oc_object = expect_single(candidates, "OrgChart #{type} named #{name} (to assign to ET #{type})")

        et_object.update_attribute(:orgchart_id, oc_object['id'])
        log.info "Assigned ET #{type} #{name} to OrgChart #{type} #{oc_object['id']}."
      end
    end

    def assign_groups
      assign_by_name('group')
    end

    def assign_users
      assign_by_name('user', :et_name_to_oc_name => lambda{|name| name.gsub(/@redhat\.com$/i, '')})
    end

    # Create UserOrganization objects for any group existing in OrgChart but not ET.
    def create_groups
      oc_groups_by_id.each do |oc_id,oc_groups|
        next unless et_groups_by_orgchart_id[oc_id].blank?

        next unless oc_group = expect_single(oc_groups, "OrgChart group with ID #{oc_id}")

        # don't create if name is ambiguous
        next unless expect_single(oc_groups_by_name[oc_group['name']], "OrgChart group with name #{oc_group['name']} (for creating an ET group with orgchart_id #{oc_id})")

        # parent/manager of group will be updated in the next step.
        et_groups_by_orgchart_id[oc_id] = [UserOrganization.create!(:name => oc_group['name'], :orgchart_id => oc_id)]
        log.info "Created new ET group #{oc_group['name']} for OrgChart group #{oc_id}."
      end
    end

    def update_groups
      et_groups_by_orgchart_id.each do |oc_id,et_groups|
        next unless et_group = expect_single(et_groups, "ET group for OrgChart group #{oc_id}")
        next unless oc_group = expect_single(oc_groups_by_id[oc_id], "OrgChart group with ID #{oc_id} (for updating ET group #{et_group.name})")

        maybe_rename_group(oc_group, et_group)
        maybe_update_group_manager(oc_group, et_group)
        maybe_update_group_parent(oc_group, et_group)
      end
    end

    def update_users
      et_users_by_orgchart_id.each do |oc_id,et_users|
        next unless et_user = expect_single(et_users, "ET user for OrgChart user #{oc_id}")
        next unless oc_user = expect_single(oc_users_by_id[oc_id], "OrgChart user with ID #{oc_id} (for updating ET user #{et_user.login_name})")

        maybe_move_user(oc_user, et_user)
      end
    end

    def maybe_rename_group(oc_group, et_group)
      return if oc_group['name'] == et_group.name
      (old,new) = [et_group.name, oc_group['name']]
      et_group.update_attribute(:name, new)
      log.info "Renamed group #{old} to #{new}."
    end

    def maybe_update_group_manager(oc_group, et_group)
      owner_name = oc_group['owner']
      return if owner_name.blank?
      return unless oc_owner = expect_single(oc_users_by_name[owner_name], "OrgChart user #{owner_name} (for manager of #{et_group.name})")

      owner_oc_id = oc_owner['id'].to_i
      return unless et_owner = expect_single(et_users_by_orgchart_id[owner_oc_id], "ET user with OrgChart ID #{owner_oc_id} (for manager of #{et_group.name})")

      return if et_group.manager_id == et_owner.id

      (old,new) = [et_group.manager.login_name, et_owner.login_name]
      et_group.update_attribute(:manager_id, et_owner.id)
      log.info "Changed manager of #{et_group.name} from #{old} to #{new}."
    end

    def maybe_update_group_parent(oc_group, et_group)
      return unless oc_group['parent']

      parent_oc_id = oc_group['parent']['id'].to_i
      return unless parent_group = expect_single(et_groups_by_orgchart_id[parent_oc_id], "ET group with OrgChart ID #{parent_oc_id} (for parent of #{et_group.name})")

      return if et_group.parent == parent_group

      (old,new) = [et_group.parent.try(:name) || '(none)', parent_group.name]
      et_group.update_attribute(:parent_id, parent_group.id)
      log.info "Changed parent of #{et_group.name} from #{old} to #{new}."
    end

    def maybe_move_user(oc_user, et_user)
      oc_group_id = oc_user['group']['id'].to_i
      return if et_user.organization.try(:orgchart_id) == oc_group_id

      return unless et_group = expect_single(et_groups_by_orgchart_id[oc_group_id], "ET group with OrgChart ID #{oc_group_id} (for user #{et_user.login_name})")

      (old,new) = [et_user.organization.try(:name) || '(none)', et_group.name]
      et_user.update_attribute(:user_organization_id, et_group.id)
      log.info "Moved #{et_user.login_name} from group #{old} to #{new}."
    end

    def expect_single(list, description)
      if list.blank?
        log.warn "Can't find any #{description}."
        return
      end

      if list.length > 1
        log.warn "Expected a single #{description}, but found #{list.length}. Skipping."
        return
      end

      list.first
    end

    def oc_client
      XMLRPC::OrgChartClient.instance
    end

    def log
      ORGCHARTLOG
    end

    def oc_groups_by_id
      @_oc_groups_by_id ||= oc_groups.group_by{|g| g['id'].to_i}
    end

    def oc_users_by_id
      @_oc_users_by_id ||= oc_users.group_by{|u| u['id'].to_i}
    end

    def et_groups_by_orgchart_id
      @_et_groups_by_orgchart_id ||= UserOrganization.where('orgchart_id IS NOT NULL').group_by(&:orgchart_id)
    end

    def et_users_by_orgchart_id
      @_et_users_by_orgchart_id ||= User.includes(:organization).where('orgchart_id IS NOT NULL').group_by(&:orgchart_id)
    end

    def oc_groups_by_name
      @_oc_groups_by_name ||= oc_groups.group_by{|g| g['name']}
    end

    def oc_users_by_name
      @_oc_users_by_name ||= oc_users.group_by{|u| u['name']}
    end

    def oc_users
      ensure_oc_loaded
      @_oc_users
    end

    def oc_groups
      ensure_oc_loaded
      @_oc_groups
    end

    def unassigned_groups_by_name
      UserOrganization.where(:orgchart_id => nil).group_by(&:name)
    end

    def unassigned_users_by_name
      User.includes(:organization).enabled.where(:orgchart_id => nil).group_by(&:login_name)
    end

    def ensure_oc_loaded
      @_oc_loaded ||= begin
        @_oc_groups = []
        @_oc_users = []

        handle_group = nil
        handle_group = lambda do |group|
          @_oc_users.concat(
            (group['users']||[]).map{|u| u.slice!(*%w[name id]); u.merge!('group' => group)}
          )

          group.slice!(*%w[name owner id parent groups])
          @_oc_groups << group

          (group['groups']||[]).each do |child|
            child.merge!('parent' => group)
            handle_group.call(child)
          end
        end

        # the top group is arbitrary set to ENG Management group
        # invoke from OrgChart xmlrpc api: getGroup
        # params:
        #
        # recursive  => A boolean. Default value is 0, list direct child groups
        # only. Set the value to 1 to list both direct and indirect child
        # groups.
        # with_users => A boolean. Default value is 0, don't list the child
        # group's members. Set the value to 1 to list the child group's
        # members.
        #
        top_group = oc_client.getGroup({:name => 'ENG Management', :recursive => 1, :with_users => 1})
        handle_group.call(top_group)

        true
      end
    end

  end
end
