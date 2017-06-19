 # Secure XMLRPC methods requiring kerberos authentication.
 # 
class SecureService
  # Method to add bugs to an advisory. Advisory must be a quarterly update or fast track errata that
  # follows the bugzilla flags model (pm_ack, etc.) 
  # 
  # <tt>advisory</tt>:: Id of the advisory, either numeric or and advisory name (RHSA-2009:9213)
  # <tt>bugids</tt>:: Array of bugzilla ids [90210, 152019, ...]
  #
  # Returns: Status message indicating bugs successfully added, or an error message
  def add_bugs_to_errata(advisory, bugids)
    user = find_user
    user.check_role_auth("Do not have permission to add bugs!", 'devel', 'pm', 'secalert')
    errata = find_errata(advisory)
    bugs = Bug.find bugids
    idsfixed = bugs.map(&:id).join(' ')
    params = AdvisoryForm.errata_to_params(errata)
    params[:advisory][:idsfixed] += " #{idsfixed}"
    form = UpdateAdvisoryForm.new(user, params)
    if form.save
      msg = "Added the following bugs:\n" + bugs.collect { |b| "bug #{b.id} - #{b.short_desc}" }.join("\n")
    else
      msg = "Error adding bugs: #{form.errors.full_messages.join(',')}"
    end
    return msg
  end

  # Method to remove bugs from an advisory
  #
  # <tt>advisory</tt>:: Id of the advisory, either numeric or and advisory name (RHSA-2009:9213)
  #
  # Returns <tt>bugids</tt>:: Array of bugzilla ids [90210, 152019, ...]
  def list_bugs_in_errata(advisory)
    errata = find_errata(advisory)
    bugids =  FiledBug.connection.select_values("select bug_id from filed_bugs where errata_id = #{errata.id}")
    return bugids.collect { |b| b.to_i }
  end

  # Method to remove bugs from an advisory. 
  # 
  # <tt>advisory</tt>:: Id of the advisory, either numeric or and advisory name (RHSA-2009:9213)
  # <tt>bugids</tt>:: Array of bugzilla ids [90210, 152019, ...]
  #
  # Returns: Status message indicating bugs successfully removed, or an error message
  def remove_bugs_from_errata(advisory, bugids)
    user = find_user
    unless user.in_role?('devel', 'pm', 'secalert')
      raise "Do not have permission to remove bugs!"
    end

    errata = find_errata(advisory)
    to_delete = FiledBug.find(:all, :conditions => ['errata_id = ? and bug_id in (?)',
                                                    errata,
                                                    bugids])
    dbs = DroppedBugSet.new(:bugs => to_delete, :errata => errata)
    if dbs.save
      msg = "Removed the following bugs:\n" + to_delete.collect { |b| "bug #{b.id}" }.join("\n")
    else
      msg = "Error dropping bugs: #{dbs.errors.full_messages.join(',')}"
    end
    return msg
  end 

  # Updates brew builds in an advisory. This method follows the same rules as the webui:
  #  Filelist is unlocked
  #  Product version is correct for advisory
  #  Build has correct tags
  # 
  # <tt>advisory</tt>:: Id of the advisory, either numeric or and advisory name (RHSA-2009:9213)
  # <tt>prod_name</tt>:: Name of the product version, same as on brew/list_files, i.e. RHEL-5
  # <tt>nvr</tt>:: NVR for the build to add
  #
  # Returns: Status message indicating bugs successfully removed, or an error message
  def update_brew_build(advisory, prod_name, nvr)
    errata = find_errata(advisory)
    return "Filelist is still locked. Please put advisory state in NEW_FILES" unless errata.status == State::NEW_FILES
    
    user = find_user
    user.check_role_auth("Do not have permission to update builds for this advisory", 'devel', 'secalert')
    
    pv = ProductVersion.find_by_name(prod_name)
    return "No such product version #{prod_name}" unless pv

    unless errata.product == pv.product
      return "Cannot use product version #{prod_name} for product #{errata.product.name}"
    end

    build = BrewBuild.make_from_rpc(nvr)
    return "Could not find build #{nvr}" unless build
    
    brew = Brew.get_connection
    has_valid_tags = brew.build_is_properly_tagged?(errata, pv, build)
    return brew.errors_to_s unless has_valid_tags
      
    old_version = ErrataBrewMapping.find(:first, 
                                         :conditions => 
                                         ['current = 1 and errata_id = ? and package_id = ?', 
                                          errata, build.package])
    
    ErrataBrewMapping.transaction do 
      ErrataBrewMapping.create(:product_version => pv,
                               :errata => errata,
                               :brew_build => build,
                               :package => build.package)
      old_version.obsolete! if old_version
      errata = Errata.find(errata.id)
      RpmdiffRun.schedule_runs(errata, user.login_name)
    end

    if old_version
      return "Updated build #{old_version.brew_build.nvr} to #{build.nvr} in #{errata.advisory_name}"
    else
      return "Added build #{build.nvr} to #{errata.advisory_name}"
    end
  end
  
  # Echoes the kerberos user back to the caller if they have credentails and are a valid errata system user,
  # otherwise throws an exception back to the caller
  def echo_user
    return find_user.to_s
  end

  
  
  private

  def find_errata(advisory)
    begin 
      return Errata.find_by_advisory(advisory)
    rescue
      raise "ERROR: No such advisory #{advisory}"
    end
  end

  def find_user
    return Thread.current[:current_user]
  end
  
end
