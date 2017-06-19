class ErrataFilter < ActiveRecord::Base
  serialize :filter_params, Hash
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :user_id

  #
  # (Still) don't like these much.
  # Why not use a list like all the other stuff? Originally done this way because the
  # form submits checkboxes. (They are checkboxes so it's easier to use '1' and '0').
  #
  def self.checkbox_param_hash(key_prefix, items)
    Hash[ items.map{ |item| ["#{key_prefix}_#{item}", '1'] } ]
  end

  EVERY_STATUS             = checkbox_param_hash('show_state', State::ALL_STATES)
  EVERY_ACTIVE_STATUS      = checkbox_param_hash('show_state', State::OPEN_STATES)
  EVERY_NOT_DROPPED_STATUS = checkbox_param_hash('show_state', State::NOT_DROPPED_STATES)
  EVERY_TYPE               = checkbox_param_hash('show_type',  ErrataType::ALL_SHORT_TYPES)

  FILTER_DEFAULTS             = {}.merge(EVERY_TYPE).merge(EVERY_ACTIVE_STATUS)
  FILTER_DEFAULTS_ALL         = {}.merge(EVERY_TYPE).merge(EVERY_STATUS)
  FILTER_DEFAULTS_NOT_DROPPED = {}.merge(EVERY_TYPE).merge(EVERY_NOT_DROPPED_STATUS)

  #
  # Don't want bare sql in query params so let's define sort options here.
  # (Will just use the keys in the form...)
  #
  # TODO: display_order sucks. should use an array. Come back to it later.
  #
  SORT_OPTIONS = {
    'new'         => { :display_order => 10, :label => 'Newest',             :sql => 'errata_main.id          DESC' },
    'old'         => { :display_order => 11, :label => 'Oldest',             :sql => 'errata_main.id          ASC'  },
    'reldate'     => { :display_order => 15, :label => 'Release Date (earliest)', :sql => 'COALESCE(publish_date_override, releases.ship_date, NOW()) ASC'  },
    'reldatedesc' => { :display_order => 16, :label => 'Release Date (latest)',   :sql => 'COALESCE(publish_date_override, releases.ship_date, NOW()) DESC' },
    'rel'         => { :display_order => 20, :label => 'Release Name (A-Z)', :sql => 'releases.name           ASC'  },
    'reldesc'     => { :display_order => 21, :label => 'Release Name (Z-A)', :sql => 'releases.name           DESC' },
    'batch'       => { :display_order => 25, :label => 'Batch Name (A-Z)',   :sql => 'batches.name            ASC'  },
    'batchdesc'   => { :display_order => 26, :label => 'Batch Name (Z-A)',   :sql => 'batches.name            DESC' },
    'prod'        => { :display_order => 30, :label => 'Product Name (A-Z)', :sql => 'errata_products.name    ASC'  },
    'proddesc'    => { :display_order => 31, :label => 'Product Name (Z-A)', :sql => 'errata_products.name    DESC' },
    'type'        => { :display_order => 40, :label => 'Errata Type (A-Z)',  :sql => 'errata_main.errata_type ASC'  },
    'typedesc'    => { :display_order => 41, :label => 'Errata Type (Z-A)',  :sql => 'errata_main.errata_type DESC' },
    'state'       => { :display_order => 50, :label => 'State',              :sql => "#{State.sort_sql}       ASC"  },
    'statedesc'   => { :display_order => 51, :label => 'State (reversed)',   :sql => "#{State.sort_sql}       DESC" },
    'unpushed'    => { :display_order => 60, :label => 'Unpushed',           :sql => 'errata_main.pushed      ASC'  },
    'pushed'      => { :display_order => 61, :label => 'Pushed',             :sql => 'errata_main.pushed      DESC' },
    'unmailed'    => { :display_order => 70, :label => 'Unmailed',           :sql => 'errata_main.mailed      ASC'  },
    'mailed'      => { :display_order => 71, :label => 'Mailed',             :sql => 'errata_main.mailed      DESC' },
    'unpublished' => { :display_order => 80, :label => 'Unpublished',        :sql => 'errata_main.published   ASC'  },
    'published'   => { :display_order => 81, :label => 'Published',          :sql => 'errata_main.published   DESC' },
    'noqa'        => { :display_order => 90, :label => 'QA Incomplete',      :sql => 'errata_main.qa_complete ASC'  },
    'qa'          => { :display_order => 91, :label => 'QA Complete',        :sql => 'errata_main.qa_complete DESC' },
    'batchblock'  => { :display_order => 95, :label => 'Batch Blocker',      :sql => 'errata_main.is_batch_blocker DESC' },
  }

  #
  # Output format options
  # Basically this selects which errata_row partial gets used.
  # (Once again, only use the keys in the form since it's more secure)
  #
  OUTPUT_FORMAT_OPTIONS = {
    'standard' => { :display_order => 10, :label => 'Standard',                  :partial => 'list_format_standard' },
    #'flags'   => { :display_order => 20, :label => 'Standard (plus flags)',     :partial => 'list_format_standard' }, # Not sure what to call it or if it is useful... TBC
    'qa'       => { :display_order => 30, :label => 'QA Requests (old style)',   :partial => 'list_format_qa_requests' },
    'sec'      => { :display_order => 40, :label => 'Secalert list (old style)', :partial => 'list_format_secalert' },
    #'docs'    => { :display_order => 50, :label => 'Docs Queue',                :partial => 'list_format_docs' }, # Disable for now
  }

  PAGINATION_OPTIONS = {
    '20'  => { :label => '20',       :value => 20 },
    '100' => { :label => '100',      :value => 100 },
    '250' => { :label => '250',      :value => 250 },
    'all' => { :label => 'Show all', :value => 20000 },
  }

  GROUP_BY_OPTIONS = {
    'none'    => {
      :label => '(none)'
    },

    'state' => {
      :label       => 'State',
      :group_by    => :status,
      :group_label => :to_s,
      :sort_by     => State.sort_sql,
      :sort_options=> %w(state statedesc)
    },

    'product' => {
      :label       => 'Product',
      :group_by    => :product,
      :group_label => :long_name,
      :sort_by     => 'errata_products.name',
      :sort_options=> %w(prod proddesc)
    },

    'release' => {
      :label       => 'Release',
      :group_by    => :release,
      :group_label => :name,
      :sort_by     => 'releases.name',
      :sort_options=> %w(rel reldesc)
    },

    'batch' => {
      :label       => 'Batch',
      :group_by    => :batch,
      :group_label => :name,
      # When grouping by batch, show advisories without batches last
      :sort_by     => 'CASE WHEN batches.name IS NULL THEN 1 ELSE 0 END, batches.name',
      :sort_options=> %w(batch batchdesc)
    },

    'qe_group' => {
      :label       => 'QE Group',
      :group_by    => :quality_responsibility,
      :group_label => :name,
      :sort_by     => 'errata_responsibilities.name',
    },

    'qe_owner' => {
      :label       => 'QE Owner',
      :group_by    => :assigned_to,
      :group_label => :short_to_s,
      :sort_by     => 'users.realname', # first join to users table is called 'users'.
    },

    #
    # Note: We have a devel_responsibility but it is not used (other than to assign all advisories
    # to the "default" devel_responsibility). Instead we use the package_owner's organization
    # as the devel group.
    #
    # The sort_by works because of the multi step join via package_owner.
    # See `join_these` below.
    #
    'devel_group' => {
      :label       => 'Devel Group',
      :group_by    => :package_owner_organization,
      :group_label => :name,
      :sort_by     => 'user_organizations.name',
    },

    'reporter' => {
      :label       => 'Reporter',
      :group_by    => :reporter,
      :group_label => :short_to_s,
      :sort_by     => 'reporters_errata_main.realname', # second join to users table, rails generates this alias. clever huh.
    },

    'release_date' => {
      :label       => 'Release Date (earliest)',
      :short_label => 'Release Date',
      :group_by    => :publish_date_for_display,
      :group_label => :to_s,
      :sort_by     => 'COALESCE(publish_date_override, releases.ship_date, NOW()) ASC',
      :sort_options=> %w(reldate)
    },

    'release_date_desc' => {
      :label       => 'Release Date (latest)',
      :short_label => 'Release Date',
      :group_by    => :publish_date_for_display,
      :group_label => :to_s,
      :sort_by     => 'COALESCE(publish_date_override, releases.ship_date, NOW()) DESC',
      :sort_options=> %w(reldatedesc)
    },
  }

  def group_by
    GROUP_BY_OPTIONS[selected_group_by]
  end

  def is_grouped?
    group_by[:group_by].present?
  end

  #
  # This SQL defines what advisories appear in the docs queue.
  #
  # The reason for testing the status as well as the text_ready flag
  # is so that if docs approval is rejected it won't disappear completely
  # from docs queue and potentially get lost.
  #
  DOCS_QUEUE_FILTER_SQL = %{
    (
      -- Not dropped
      is_valid = 1
      -- Not already approved
      AND doc_complete = 0
      AND ((
          -- Any time the docs requested flag is set
          text_ready = 1
          -- And advisory still active
          AND status NOT IN ('SHIPPED_LIVE', 'DROPPED_NO_SHIP')
        ) OR (
          -- Any time the advisory is in REL_PREP or PUSH_READY. See Bz 782277
          -- Include QE as well now. See Bz 809216.
          -- (Actually should never be in PUSH_READY without docs approval. See Bz 671525)
          status IN ('QE', 'REL_PREP', 'PUSH_READY')
      ))
    )
  }

  #
  # This is a bit different to the others because will use a chosen multi-select.
  #
  # Note: Sorting/group by docs status is going to be a bit tricky.
  # The group by might be solved by a/m/docs_status but still need to sort
  # in sql so some even more ugly sql would be needed in 'order by'.
  # Come back to this later maybe.
  #
  # "#{DOCS_QUEUE_FILTER_SQL} AND text_ready = 1" makes some extremely ugly
  # sql even though it works correctly.. Fixme?
  #
  DOCS_STATUS_OPTIONS = {
    'not_reqd'    => { :display_order => 1, :label => 'Not Requested',           :sql => "(NOT #{DOCS_QUEUE_FILTER_SQL} AND doc_complete = 0)" },
    # Since this means the same as requested and need_redraft together it is confusing. leave it out... (see Bug 836927)
    #'in_queue'    => { :display_order => 2, :label => 'In Docs Queue',           :sql => "(#{DOCS_QUEUE_FILTER_SQL})"                          },
    'requested'   => { :display_order => 3, :label => 'In Queue (Requested)',    :sql => "(#{DOCS_QUEUE_FILTER_SQL} AND text_ready = 1)"       },
    'need_redraft'=> { :display_order => 4, :label => 'In Queue (Needs redraft)', :sql => "(#{DOCS_QUEUE_FILTER_SQL} AND text_ready = 0)"       },
    'approved'    => { :display_order => 5, :label => 'Approved' ,               :sql => "(doc_complete = 1)"                                  },
  }

  SECURITY_APPROVAL_OPTIONS = {
    'not_requested' => { :display_order => 1, :label => 'Not Requested', :value => nil },
    'requested' => { :display_order => 2, :label => 'Requested', :value => false },
    'approved' => { :display_order => 3, :label => 'Approved', :value => true },
  }

  #
  # For filtering by open/closed
  #
  OPEN_CLOSED_OPTIONS = {
    'exclude' => { :display_order => 1, :label => 'Exclude closed',   :sql => "(closed = 0)" },
    'only'    => { :display_order => 2, :label => 'Show only closed', :sql => "(closed = 1)" },
  }

  # For filtering by text only flag
  #
  TEXT_ONLY_OPTIONS = {
    'exclude' => { :display_order => 1, :label => 'Exclude text only', :sql => "(text_only = 0)" },
    'only'    => { :display_order => 2, :label => 'Just text only',    :sql => "(text_only = 1)" },
  }

  after_initialize do
    self.filter_params ||= FILTER_DEFAULTS
  end

  # These are just scopes, but why bother with the scope method and lambdas, since this is clearer and more readable...
  def self.for_user(user)
    where('user_id = ?', user.id)
  end

  #
  # These are shown as checkboxes on the form.
  # (Note if RHEA is checked the filter will include RHEA and PdcRHEA and so on)
  #
  def selected_types
    [
     (['RHEA', 'PdcRHEA'] if filter_params['show_type_RHEA'].to_bool),
     (['RHBA', 'PdcRHBA'] if filter_params['show_type_RHBA'].to_bool),
     (['RHSA', 'PdcRHSA'] if filter_params['show_type_RHSA'].to_bool),
    ].compact.flatten
  end

  def selected_types_text
    if selected_types.length == 3
      nil
    else
      "#{selected_types.join(', ')}"
    end
  end

  def selected_statuses
    [
     ('NEW_FILES'       if filter_params['show_state_NEW_FILES'      ].to_bool),
     ('QE'              if filter_params['show_state_QE'             ].to_bool),
     ('REL_PREP'        if filter_params['show_state_REL_PREP'       ].to_bool),
     ('PUSH_READY'      if filter_params['show_state_PUSH_READY'     ].to_bool),
     ('IN_PUSH'         if filter_params['show_state_IN_PUSH'        ].to_bool),
     ('SHIPPED_LIVE'    if filter_params['show_state_SHIPPED_LIVE'   ].to_bool),
     ('DROPPED_NO_SHIP' if filter_params['show_state_DROPPED_NO_SHIP'].to_bool),
    ].compact
  end

  def selected_statuses_text
    if selected_statuses == ['NEW_FILES','QE','REL_PREP','PUSH_READY', 'IN_PUSH', 'SHIPPED_LIVE','DROPPED_NO_SHIP']
      "All states"
    elsif selected_statuses == ['NEW_FILES','QE','REL_PREP','PUSH_READY']
      "Active"
    else
      "State #{selected_statuses.map{ |s| State.nice_label(s,:short=>true) }.join(', ')}"
    end
  end

  # Helper for select_* methods
  def selected_ids(what_param)
    id_list = filter_params[what_param]
    id_list.present? && !id_list.empty? && id_list.map(&:to_i)
  end

  # Helper for select_*_text methods
  def selected_ids_text(what_param, label, record_class, name_method=:name)
    ids = selected_ids(what_param)
    label = "Not #{label}" if selected_negate?(what_param)
    record_class ||= what_param.titleize.constantize
    "#{label}: #{ids.map{ |record_id| record_class.find(record_id).send(name_method) rescue 'none' }.join(', ')}" if ids
  end

  # TODO: Could do some meta programming DRY stuff here...
  def selected_products    ; selected_ids('product'    ); end
  def selected_releases    ; selected_ids('release'    ); end
  def selected_batches     ; selected_ids('batch'      ); end
  def selected_qe_groups   ; selected_ids('qe_group'   ); end
  def selected_qe_owners   ; selected_ids('qe_owner'   ); end
  def selected_devel_groups; selected_ids('devel_group'); end
  def selected_reporters   ; selected_ids('reporter'   ); end

  def selected_content_types; filter_params['content_types']; end
  def selected_open_closed_option; filter_params['open_closed_option']; end
  def selected_text_only_option; filter_params['text_only_option']; end

  # default sort is newest first..
  def selected_sort_by_fields   ; (filter_params['sort_by_fields']   || ['new']).uniq   ; end

  def selected_output_format    ; filter_params['output_format']     || 'standard' ; end
  def selected_pagination_option; filter_params['pagination_option'] || '20'       ; end
  def selected_group_by         ; filter_params['group_by']          || 'none'     ; end

  def selected_in_docs_queue;  filter_params[:in_docs_queue].present?; end

  def selected_products_text    ; selected_ids_text('product',     'Product',     Product,              :short_name) ; end
  def selected_releases_text    ; selected_ids_text('release',     'Release',     Release                          ) ; end
  def selected_batches_text     ; selected_ids_text('batch',       'Batch',       Batch                            ) ; end
  def selected_qe_groups_text   ; selected_ids_text('qe_group',    'QE Group',    QualityResponsibility            ) ; end
  def selected_devel_groups_text; selected_ids_text('devel_group', 'Devel Group', UserOrganization                 ) ; end

  def selected_content_types_text
    if selected_content_types
      (selected_negate?('content_types') ? 'Not ' : '') +
        "Content Type: #{selected_content_types.join(', ')}"
    end
  end

  def selected_qe_owners_text
    if filter_params['qe_owner_is_me']
      return selected_negate?('qe_owner') ? 'Not assigned to you' : 'Assigned to you'
    else
      selected_ids_text('qe_owner', 'Assigned To', User, :short_name)
    end
  end

  def selected_reporters_text
    if filter_params['reporter_is_me']
      return selected_negate?('reporter') ? 'Not reported by you' : 'Reported by you'
    else
      selected_ids_text('reporter', 'Reported By', User, :short_name)
    end
  end

  def selected_sort_by_fields_names  ; selected_sort_by_fields.map{|f|SORT_OPTIONS[f][:label]} ; end
  def selected_output_format_name    ; OUTPUT_FORMAT_OPTIONS[selected_output_format][:label].sub('(old style)','') ; end
  def selected_group_by_name         ; GROUP_BY_OPTIONS[selected_group_by][:label]             ; end
  def selected_pagination_option_name; PAGINATION_OPTIONS[selected_pagination_option][:label]  ; end

  def selected_sort_by_fields_text
    # Hacky..
    "sorted by #{selected_sort_by_fields_names.join(' then by ')}".downcase unless selected_sort_by_fields.empty?
  end

  def selected_doc_status_options
    key_list = filter_params['doc_status']
    key_list.present? && !key_list.empty? && key_list
  end

  def selected_doc_status_options_text
    # hacky. need to clean this up a bit..
    "docs #{selected_doc_status_options.map{|o|DOCS_STATUS_OPTIONS[o][:label]}.join(", ")}".downcase if selected_doc_status_options
  end

  def selected_security_approval_options
    filter_params.fetch('security_approval', [])
  end

  def selected_security_approval_options_text
    options_text = selected_security_approval_options.map{|o|SECURITY_APPROVAL_OPTIONS[o][:label].downcase}.sort.join(', ')
    "security approval #{options_text}" if selected_security_approval_options.any?
  end

  def selected_exclude_rhel7_opt?
    filter_params['exclude_rhel7'].to_bool
  end

  def selected_negate?(what_param)
    filter_params["#{what_param}_not"].to_bool
  end

  def build_clause(field, selected_values, what_param)
    # check if 'not' checkbox is checked
    negate = selected_negate?(what_param)

    have_nil = selected_values.include?(nil)
    selected_values = selected_values.dup
    selected_values.delete(nil)

    sql = [
      ("#{field} in (?)" if selected_values.present?),
      ("#{field} is NULL" if have_nil)
    ].compact.join(' OR ')

    if sql.empty?
      raise ArgumentError, "Error while building sql clause. No value is selected."
    end

    if negate
      sql = "NOT (#{sql})"
      if !have_nil
        # Since NULL is not equal to anything, if nil was not one of
        # the requested values, every NULL value should match.
        #
        # This is needed due to the possibly unintuitive result that:
        #
        #   NOT (x in ("a","b","c"))
        #
        # ... does not match an x of NULL.
        sql = "#{sql} OR #{field} is NULL"
      end
    end

    [sql, (selected_values if selected_values.present?)].compact
  end

  def errata_row_partial
    OUTPUT_FORMAT_OPTIONS[selected_output_format][:partial]
  end

  def per_page
    PAGINATION_OPTIONS[selected_pagination_option][:value] || 100
  end

  def selected_open_closed_option_text
    OPEN_CLOSED_OPTIONS[selected_open_closed_option][:label].downcase if selected_open_closed_option.present?
  end

  def selected_text_only_option_text
    TEXT_ONLY_OPTIONS[selected_text_only_option][:label].downcase if selected_text_only_option.present?
  end

  def selected_output_format_text
    case selected_output_format
    when 'standard'
      nil
    else
      "#{selected_output_format_name.downcase}"
    end
  end

  def selected_group_by_text
    case selected_group_by
    when 'none'
      nil
    else
      "grouped by #{selected_group_by_name}"
    end
  end


  def synopsis_text_search
    filter_params['synopsis_text']
  end

  def synopsis_text_search_text
    "Synopsis: '#{synopsis_text_search}'" if synopsis_text_search.present?
  end

  #
  # Let's put all the errata filtering logic here
  # instead of in the controller.
  #
  # (It might possibly more correctly belong in the errata model, but
  # things are pretty cluttered over there..)
  #
  # Going to be applying chained active relations on the Errata model
  # basically.
  #
  def results(opts={})
    #
    # Just a place to start chaining things.
    #
    filter_results = Errata.scoped

    #
    # Filter by advisory type
    #
    filter_results = filter_results.where('errata_main.errata_type in (?)', selected_types)

    #
    # Filter by advisory status
    #
    filter_results = filter_results.where('errata_main.status in (?)', selected_statuses)

    #
    # Filter by selected products
    # (If none are selected, then show all products)
    #
    if selected_products
      args = build_clause("errata_main.product_id", selected_products, 'product')
      filter_results = filter_results.where(*args)
    end

    # Deprecated. Some users may still have this option saved.
    # To prevent breaking the saved filter, we need to convert
    # it to the new negate filter function.
    if selected_exclude_rhel7_opt?
      # do negate filter to exclude rhel-7.* releases
      filter_params['release_not'] = '1'
      filter_params['release'] = Release.where("name like 'RHEL-7.%'").map(&:id)
    end

    #
    # Filter by selected releases
    # (If none are selected, then show all releases)
    #
    if selected_releases
      args = build_clause("errata_main.group_id", selected_releases, 'release')
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by Batch
    #
    if selected_batches
      args = build_clause("errata_main.batch_id", selected_batches.map{|x| x == 0 ? nil : x}, 'batch')
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by Content Types
    #
    if selected_content_types
      types = selected_content_types.dup
      sql = []
      if types.delete('None')
        sql << "errata_main.content_types = '#{[].to_yaml}'"
      end
      sql.concat ["errata_main.content_types LIKE ?"] * types.length
      sql = sql.join(' OR ')
      sql = "NOT (#{sql})" if selected_negate?('content_types')
      args = [ sql, *(types.map{|x| "% #{x}\n%"})]
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by QE group
    #
    if selected_qe_groups
      args = build_clause("errata_main.quality_responsibility_id", selected_qe_groups, 'qe_group')
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by Devel group
    #
    # Note: We have a devel_responsibility but it is not used (other than to assign all advisories
    # to the "default" devel_responsibility). Instead we use the package_owner's organization
    # as the devel group.
    #
    # There is a join (see `join_these` below) that joins the user_organizations table via package
    # owner (ie, the users table).
    #
    if selected_devel_groups
      args = build_clause("user_organizations.id", selected_devel_groups, 'devel_group')
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by QE owner
    #
    if filter_params['qe_owner_is_me']
      args = build_clause("errata_main.assigned_to_id", [User.current_user], 'qe_owner')
      filter_results = filter_results.where(*args)
    elsif selected_qe_owners
      args = build_clause("errata_main.assigned_to_id", selected_qe_owners, 'qe_owner')
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by reporter
    #
    if filter_params['reporter_is_me']
      args = build_clause("errata_main.reporter_id", [User.current_user], 'reporter')
      filter_results = filter_results.where(*args)
    elsif selected_reporters
      args = build_clause("errata_main.reporter_id", selected_reporters, 'reporter')
      filter_results = filter_results.where(*args)
    end

    #
    # Filter by "in docs queue"
    # This is a bit different. We will define what "in docs queue" means
    # using some hand crafted sql.
    #
    # NOT CURRENTLY USED. POSSIBLY OBSOLETED BY selected_doc_status_options...
    #
    if selected_in_docs_queue
      filter_results = filter_results.where(DOCS_QUEUE_FILTER_SQL)
    end

    #
    # Have to use hand crafted SQL here because docs status schema is not designed well.
    # Warning, this is going to make some pretty ugly sql, especially if user chooses a few options...
    #
    if selected_doc_status_options
      sql = selected_doc_status_options.map { |doc_status| DOCS_STATUS_OPTIONS[doc_status][:sql] }.join(" OR ")
      filter_results = filter_results.where(sql)
    end

    #
    # Filter by security approval status
    #
    if (security_opts=selected_security_approval_options).present?
      values = SECURITY_APPROVAL_OPTIONS.slice(*security_opts).map{|k,v| v[:value]}
      args = build_clause("errata_main.security_approved", values, 'security_approval')
      filter_results = filter_results.where(*args)
    end

    #
    # Filtering by the "closed" flag.
    # (Seems a bit untidy..)
    #
    if selected_open_closed_option.present?
      filter_results = filter_results.where(OPEN_CLOSED_OPTIONS[selected_open_closed_option][:sql])
    end
    # Filtering by the text only flag
    #
    if selected_text_only_option.present?
      filter_results = filter_results.where(TEXT_ONLY_OPTIONS[selected_text_only_option][:sql])
    end

    #
    # Filter by synopsis query text
    #
    if synopsis_text_search.present?
      filter_results = filter_results.where('errata_main.synopsis like ?', "%#{synopsis_text_search}%")
    end

    #
    # Include a few commonly used associated records to save subsequent db hits
    # Without the joins, the sql snippets above won't work.
    #
    # Note that we are being lazy and joining everything whether it is needed or not.
    # Could probably improve speed by only joining stuff that is required by the filter.
    #
    join_these = [
                  :product,
                  :assigned_to,
                  :release,
                  :quality_responsibility,
                  :docs_responsibility,
                  :reporter,
                  # This is a multi step join needed for devel group filtering (instead of :devel_responsibility)
                  {:package_owner => :organization}
                 ]

    filter_results = filter_results.joins(*join_these)

    #
    # Do some includes to ensure that the errata records get their release, product etc
    # pre-populated and don't require subsequent extra db hits.
    #
    # Batch is included here, and not in join_these, as not all errata have a batch
    # (these relations are LEFT OUTER JOINed in the SQL query).
    #
    included_not_joined = [
                           :filed_bugs,
                           :batch
                          ]
    include_these = join_these + included_not_joined
    filter_results = filter_results.includes(*include_these)

    #
    # Because of the way we do grouping we must sort by whatever the group_by is.
    # (And we must do that first, before the other sort options).
    #
    # Was going to do a filter_results.group_by{ |e| ... } here,
    # BUT... not sure how to paginate the grouped hash.
    #
    # So instead will do it a more clumsy way by render group headings
    # while iterating over the errata list. See list_format_standard.
    #
    # It means that groups might span a page due to the pagination, but
    # not sure how else to do it.
    #
    # If primary sort field is for the same column as group_by, then avoid
    # sorting by group_by. This allows user to control asc/desc group order.
    #
    if is_grouped? && !group_by[:sort_options].try(:include?, selected_sort_by_fields.first)
      filter_results = filter_results.order(group_by[:sort_by])
    end

    #
    # The form only shows two sort fields but let's make it so we can
    # have an arbitrary amount. Note that the order is significant.
    #
    selected_sort_by_fields.each do |sort_field|
      filter_results = filter_results.order(SORT_OPTIONS[sort_field][:sql])
    end

    #
    # Do pagination here
    # (Debatably not a great idea, since pagination is presentation thing..)
    #
    filter_results = filter_results.paginate(:page => opts[:page], :per_page => per_page)

    #
    # Enforce a limit on the number of items returned
    #
    filter_results = filter_results.
      extend(RelationFetchLimiter).
      fetch_limit(Settings.max_filter_items)

    # After everything is done, we want to update the old filter format to the new format.
    if !new_record? && selected_exclude_rhel7_opt?
      filter_params.delete('exclude_rhel7')
      update_attributes(:filter_params => filter_params)
    end

    #
    # All done, return
    #
    filter_results
  end

  def in_words
    result = [
              selected_types_text,
              selected_statuses_text,
              selected_text_only_option_text,
              selected_products_text,
              selected_releases_text,
              selected_batches_text,
              selected_content_types_text,
              selected_qe_groups_text,
              selected_qe_owners_text,
              selected_devel_groups_text,
              selected_reporters_text,
              selected_doc_status_options_text,
              selected_security_approval_options_text,
              selected_open_closed_option_text,
              synopsis_text_search_text,
              selected_sort_by_fields_text,
              selected_output_format_text,
              selected_group_by_text,
             ].compact.join('; ')

    # Tweak for readability
    if result == 'Active'
      result = 'All active advisories'
    end

    result
  end

  [
    [:sort, SORT_OPTIONS],
    [:format, OUTPUT_FORMAT_OPTIONS],
    [:pagination, PAGINATION_OPTIONS],
    [:group_by, GROUP_BY_OPTIONS],
    [:docs_status, DOCS_STATUS_OPTIONS],
    [:security_approval, SECURITY_APPROVAL_OPTIONS],
    [:open_closed, OPEN_CLOSED_OPTIONS],
    [:text_only, TEXT_ONLY_OPTIONS],
  ].each do |key, options_hash|
    (class << self; self; end).send(:define_method, "#{key}_options_for_select") do |*args|
      self.send(:select_options_from_hash, *args.unshift(options_hash))
    end
  end

  # Special handling for pagination options.
  # We want to hide the 'all' option in most contexts, but we still accept it
  # when performing the pagination, and allow it to be shown if the filter
  # already is using it.
  def pagination_options_for_select(*args)
    options = self.class.pagination_options_for_select(*args)
    if selected_pagination_option != 'all'
      options.reject!{|_, val| val == 'all'}
    end
    options
  end

  private

  def self.select_options_from_hash(h, exclude=nil)
    h.sort_by{|k,v| [v[:display_order] || '', v[:value] || '', v[:label] || '', k]}.map{|k,v| [v[:label], k] unless k == exclude}.compact
  end
end
