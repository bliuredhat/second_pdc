#
# Implementation of Errata XMLRPC Server API defined in app/apis/errata_api.rb
#map = Secalert::CpeMapper.cpe_map_since '2007-01-01'

class ErrataService
  include ActionView::Helpers::UrlHelper

  def ping
    true
  end

  # Returns the list of packages for an advisory, tied to RHEL release and package version.
  # Utilized by RHTS.
  #
  # Expects: <tt>advisory</tt>:: Advisory string (RHSA-2010:9999) or numeric id.
  # Returns:
  #  [{"packages"=>["foobar-debuginfo", "foobar-devel", "foobar-libs", "foobar"],
  #   "rhel_version"=>"RHEL-5",
  #   "version"=>"1.0.3-4.el5_2"},
  #  {"packages"=>["foobar-devel", "foobar-libs", "foobar"],
  #   "rhel_version"=>"RHEL-2.1",
  #   "version"=>"1.0.1-5.EL2.1"},
  #  {"packages"=>["foobar-debuginfo", "foobar-devel", "foobar-libs", "foobar"],
  #   "rhel_version"=>"RHEL-3",
  #   "version"=>"1.0.2-12.EL3"},
  #  {"packages"=>["foobar-debuginfo", "foobar-devel", "foobar-libs", "foobar"],
  #   "rhel_version"=>"RHEL-4",
  #   "version"=>"1.0.2-14.el4_7"}]
  def get_base_packages_rhts(advisory)
    errata = find_errata(advisory)
    packages = []
    # TODO: Support PDC
    return packages if errata.blank? || errata.is_pdc?

    errata.build_mappings.each do |m|
      hash = {}
      hash[:rhel_version] = m.release_version.rhel_release.name
      hash[:version] = "#{m.brew_build.version}-#{m.brew_build.release}"
      hash[:packages] = m.brew_build.brew_rpms.collect {|r| r.name_nonvr}.to_set.to_a
      packages << hash
    end
    return packages
  end

  # Method for performing ad-hock queries on errata data. Originally written by Dennis Gregorovic
  # for releng use on errata-legacy and ported to Ruby.
  #
  # The method takes a hash of parameters and returns a list hashes containing information about
  # the advisories found.
  # Input parameters - At least one of the following must be used, but several can be combined:
  #
  # <tt>id</tt>:: Id of the advisory, either numeric or and advisory name (RHSA-2009:9213)
  # <tt>product</tt>:: Array of short product names (RHEL, LACD) as seen on https://errata.devel.redhat.com/errata/list
  # <tt>product_version</tt>:: Array of product version names; only return errata with builds in these product versions
  # <tt>release</tt>:: Release as seen on https://errata.devel.redhat.com/errata/list
  # <tt>synopsis</tt>:: Fragment of an advisory synopsis
  # <tt>errata_type</tt>:: Errata type (RHSA, RHBA, or RHEA)
  # <tt>statuses</tt>:: <em>Array</em> of statuses (e.g. ['NEW_FILES','QE'])
  # <tt>qe_owner</tt>:: QE owner login name (redhat email address)
  # <tt>qe_group</tt>:: QE group name (e.g. 'BaseOS QE - Daemons', 'Cluster-Storage', 'Virt QE' ...)
  # <tt>pkg_owner</tt>:: Package owner login name (redhat email address)
  # <tt>bugs</tt>:: <em>Array</em> of bugs (e.g. [123456,12345] )
  # <tt>package</tt>:: Package name (e.g. 'kernel', 'sudo', 'glibc' ...)
  # <tt>created_at</tt>:: XMLRPC datetime. Condition is "errata.created > param"
  # <tt>updated_at</tt>:: XMLRPC datetime. Condition is "errata.updated > param"
  # <tt>issue_date_lte</tt> :: XMLRPC datetime. Condition is "errata.issue_date <= param"
  # <tt>issue_date_gt</tt> :: XMLRPC datetime. Condition is "errata.issue_date > param"
  # <tt>update_date_lte</tt> :: XMLRPC datetime. Condition is "errata.updated <= param"
  # <tt>update_date_gt</tt> :: XMLRPC datetime. Condition is "errata.updated > param"
  # <tt>files</tt>:: If true, includes a list of all files included in this advisory
  # <tt>report</tt>:: If true, includes bug ids fixed and the e-mail of the person who filed the advisory
  # <tt>per_page</tt>:: Max number of results to return per request
  # <tt>page</tt>:: Page number (starting at 1); use with per_page to paginate through many results
  #
  # Note that performing a query with a large number of results, without specifying a per_page parameter,
  # may cause a fatal error.
  #
  # Output is a list of hashes with the following data:
  #
  # <tt>status</tt>:: Current errata state (ON_QA, NEED_DEV, etc).
  # <tt>advisory_name</tt>:: Full advisory name (RHSA-2009:9123-07)
  # <tt>synopsis</tt>:: Errata synopsis
  # <tt>errata_id</tt>:: Numeric id of advisory
  # <tt>priority</tt>:: Priority of the advisory
  # <tt>product</tt>:: Product (LACD, RHEL, etc.)
  # <tt>errata_type</tt>:: One of RHSA, RHBA, or RHEA
  # <tt>files</tt>:: list of files in the advisory:  ['/mnt/brewroot/foo/...', ...]
  # <tt>idsfixed</tt>:: List of bug ids fixed: [90210,41721,...],
  # <tt>reporter</tt>:: E-mail of person who filed the advisory
  #
  #
  # The files portion in the return maps is only included if 'files' is specified
  # in the input.  Likewise for 'report'.  Porting this method as-is would also
  # solve most of the errata-group-status issues that I mentioned separately in
  # email.
  #
  # # TODO: Support PDC
  def get_advisory_list(params)
    errata = []

    if params['id']
      er = find_errata(params['id'])
      errata << er if er
    else
      cond = get_advisory_list_conditions(params)
      errata = LegacyErrata.where(cond[:conditions]).includes(cond[:include])
      if params['per_page']
        errata = errata.paginate(:page => params.fetch('page', 1), :per_page => params['per_page'])
      end

      errata.extend(RelationFetchLimiter)

      # Do not allow more than this number of items to be fetched
      # (avoid performance issues).
      max_items = Settings.max_advisory_list_items

      # Decrease the max further if additional data was requested.
      #
      # These scale factors are based on rough testing with a filter returning
      # all advisories in the DB.  The factors were picked to keep the runtime
      # roughly between 30-60 seconds if the query returns exactly max_items
      # items.
      max_items /= 4 if params['files']
      max_items /= 2 if params['report']
      max_items /= 8 if params['can_push']

      errata = errata.fetch_limit(max_items)
    end

    advisory_list = []
    errata.each do |e|

      hash = {
        :advisory_name => e.fulladvisory,
        :errata_id => e.id,
        :status => e.status.to_s,
        :synopsis => e.synopsis,
        :priority => e.priority,
        :product => e.product.short_name,
        :errata_type => e.short_errata_type,
        :created_at => e.created_at.to_s,
        :actual_ship_date => e.actual_ship_date.to_s
      }
      if params['files']
        files = Set.new
        e.current_files.each { |f| files << f.devel_file }
        hash[:files] = files.to_a
      end
      if params['report']
        hash[:idsfixed] = e.bugs.collect(&:id)
        hash[:reporter] = e.reporter.login_name
      end
      if params['can_push']
        hash[:live_push_info] = RhnLivePushJob.new(:errata => e).push_details # TODO FIXME pushed_by?
        hash[:stage_push_info] = RhnStagePushJob.new(:errata => e).push_details
        hash[:ftp_push_info] = FtpPushJob.new(:errata => e).push_details
      end
      advisory_list << hash
    end

    advisory_list
  end

  def get_advisory_rhn_metadata(advisory, do_shadow = false)
    errata = find_errata(advisory)
    return { } unless errata
    r = Push::Rhn.make_hash_for_push(errata, 'release-engineering@redhat.com', do_shadow)
    r.delete "packages"
    r
  end

  #
  # See documentation here:
  #   https://mojo.redhat.com/docs/DOC-1127431#jive_content_id_erratum
  #
  def get_advisory_cdn_metadata(advisory, do_shadow = false)
    errata = find_errata(advisory)
    return { } if !errata

    errata_to_pulp_maps = {
      'advisory_name' => 'id',
      'synopsis' => 'title',
      'description' => 'description',
      'revision' => 'version',
      'short_errata_type' => 'type',
      'update_date' => 'updated',
      'issue_date' => 'issued',
      'security_impact' => 'severity',
      'topic' => 'summary',
      'solution' => 'solution',
    }

    pulp = {
      'release' => '0',
      'status' => 'final',
      'pushcount' => errata.revision,
      'reboot_suggested' => false,
      'references' => [],
      'pkglist' => [],
      'from' => 'release-engineering@redhat.com',
      'rights' => "Copyright #{errata.advisory_name.scan(/[^-:]+/)[1]} Red Hat Inc",
    }

    pulp['reboot_suggested'] = errata.reboot_suggested?

    errata_to_pulp_maps.each_pair do |e_field, p_field|
      pulp[p_field] = errata.send(e_field).to_s
    end

    # link to advisory itself
    rhn_ref = {
      'href' => 'https://access.redhat.com/errata/%s' % pulp['id'],
      'type' => 'self',
      'id' => pulp['id'],
      'title' => pulp['id'],
    }
    pulp['references'] << rhn_ref

    # links to bugs in Red Hat Bugzilla
    errata.bugs.each do |b|
      next if b.is_private?
      bug_ref = {
        'href' => "https://bugzilla.redhat.com/show_bug.cgi?id=#{b.bug_id}",
        'type' => 'bugzilla',
        'title' => b.short_desc,
        'id' => b.bug_id.to_s,
      }
      pulp['references'] << bug_ref
    end

    # CVE links
    if (cve_list = errata.all_cves).any?
      cve_list.each do |cve|
        cve_ref = {
          'href' => "https://www.redhat.com/security/data/cve/#{cve}.html",
          'type' => 'cve',
          'id' => cve,

          'title' => cve,
        }
        pulp['references'] << cve_ref
      end
    end

    # classification link
    severity = errata.security_impact.downcase
    if %w[low moderate important critical].include?(severity)
      cl_ref = {
        'href' => "https://access.redhat.com/security/updates/classification/\##{severity}",
        'type' => 'other',
        'id' => 'classification',
        'title' => severity,
      }
      pulp['references'] << cl_ref
    end

    # other links
    if errata.reference
      # don't want to add duplicates
      existing_hrefs = pulp['references'].map{|r| r['href']}
      references = errata.reference.split("\n") - existing_hrefs
      pulp['references'] += references.map.with_index do |ref, i|
        {
          'href' => ref,
          'type' => 'other',
          'id' => "ref_#{i}",
          'title' => "other_reference_#{i}",
        }
      end
    end

    pkg_ref_list = []
    seen_files = Set.new
    # Not sure it is correct to use this method here, let me know if this is wrong
    # This will skip the rpm if there is no repo found for it.
    cdn_rpm_repo_map(errata, do_shadow) do |brew_build, rpm, variant, arch, repos, mapped_repos|
      next if seen_files.include?(rpm.rpm_name)
      seen_files << rpm.rpm_name

      pkg_ref = {
        'name' => rpm.name_nonvr,
        'version' => rpm.version,
        'release'=> rpm.release,
        'epoch' => rpm.epoch,
        'arch' => rpm.arch.name,
        'filename' => rpm.rpm_name,
        'sum' => ['md5', rpm.md5sum, 'sha256', rpm.sha256sum ],
        'src' => brew_build.srpm.rpm_name,
      }

      # Note this is intentionally not set on the hash at all if the value is false,
      # for backwards-compatibility. (<reboot_suggested> with a value of false has never
      # appeared in updateinfo XML generated by RHN or pulp, so let's keep it that way.)
      if errata.reboot_suggested?
        pkg_ref['reboot_suggested'] = true
      end

      pkg_ref_list << pkg_ref
    end

    packages = {
      'packages' => pkg_ref_list.sort_by{|p| p['filename']},
      'name' => pulp['id'],
      'short' => '',
    }
    pulp['pkglist'] << packages

    if errata.text_only? || errata.has_docker?
      pulp['cdn_repo'] = errata.text_only_channel_list.get_cdn_repos.map(&:name).sort
    end

    pulp_user_metadata = {
      'content_types' => errata.content_types
    }
    pulp['pulp_user_metadata'] = pulp_user_metadata

    pulp
  end

  def get_advisory_rhn_file_list(advisory, use_shadow = false)
    out = Hash.new { |hash, key| hash[key] = { }}
    errata = find_errata(advisory) || raise("Can't find errata '#{advisory}'")
    rpm_channel_mapping(errata, :shadow => use_shadow) do |brew_build, rpm, variant, arch, channels, mapped_channels|
      nvr = brew_build.nvr
      out[nvr]['sig_key'] ||= brew_build.sig_key.keyid
      out[nvr]['rpms'] ||= HashList.new
      names = (channels + mapped_channels).collect {|c| c.name}
      names.collect! {|c| c += '-shadow'} if use_shadow
      names.collect! {|c| c += '-debuginfo'} if rpm.is_debuginfo?
      names.reject!(&:blank?)
      out[nvr]['rpms'][rpm.rpm_name].concat(names).tap(&:uniq!).tap(&:sort!) unless names.empty?
      ( out[nvr]['checksums'] ||= CheckSumList.new ) << rpm
    end
    out
  end

  def get_advisory_rhn_nonrpm_file_list(advisory, use_shadow = false)
    errata = find_errata(advisory) || raise("Can't find errata '#{advisory}'")
    filemeta = BrewFileMeta.find_or_init_for_advisory(errata)

    out = Hash.new{|h,k| h[k] = {}}

    file_channel_mapping(errata, :shadow => use_shadow) do |brew_build, file, variant, arch, channels|
      next if file.kind_of?(BrewRpm)

      meta = filemeta.find{|m| m.brew_file == file}

      out[brew_build.nvr][file.filename_with_subpath] = {
        'id' => file.id_brew,
        'title' => meta.title,
        'display_order' => meta.rank,
        'channels' => channels.map(&:name).sort
      }
    end

    out
  end

  def get_advisory_cdn_file_list(advisory, use_shadow = false)
    errata = find_errata(advisory)
    file_list = Hash.new { |hash, key| hash[key] = { 'rpms' => HashList.new }}
    cdn_rpm_repo_map(errata, use_shadow) do |brew_build, rpm, variant, arch, repos, mapped_repos|
      repo_names = get_repo_names(repos, mapped_repos, use_shadow)
      file_list[brew_build.nvr]['rpms'][rpm.rpm_name].concat(repo_names).tap(&:uniq!).tap(&:sort!)
      ( file_list[brew_build.nvr]['checksums'] ||= CheckSumList.new ) << rpm
      file_list[brew_build.nvr]['sig_key'] ||= brew_build.sig_key.keyid
    end
    file_list
  end

  def get_advisory_cdn_nonrpm_file_list(advisory, use_shadow = false)
    errata = find_errata(advisory) || raise("Can't find errata '#{advisory}'")
    file_list = Hash.new { |hash, key| hash[key] = { 'archives' => {} }}
    filemeta = BrewFileMeta.find_or_init_for_advisory(errata)

    cdn_file_repo_map(errata, use_shadow) do |brew_build, file, variant, arch, repos, mapped_repos|
      next if file.kind_of?(BrewRpm)

      repo_names = get_repo_names(repos, mapped_repos, use_shadow)

      meta = filemeta.find{|m| m.brew_file == file}
      file_key = [file.file_subpath, file.filename].reject(&:blank?).join('/')

      file_list[brew_build.nvr]['archives'][file_key] ||= {
        'id' => file.id_brew,
        'title' => meta.title,
        'display_order' => meta.rank,
        'repos' => [],
      }
      file_list[brew_build.nvr]['archives'][file_key]['repos'].concat(repo_names).tap(&:uniq!).tap(&:sort!)
    end
    file_list
  end

  #
  # Get the CDN docker metadata for an advisory.
  #
  # Example response:
  # {
  #   "rhel-server-docker-7.1-3" => {
  #     "docker" => {
  #       "rhel-server-docker-7.1-3.x86_64.tar.gz" => {
  #         "repos" => {
  #           "test_docker_7-1" => {
  #             "tags" => ["latest", "3-7.1"]
  #           }
  #         }
  #       }
  #     }
  #   }
  # }
  #
  # Overview of the logic:
  # - For each docker image filed on each product version in the advisory
  # --  Look up all of the enabled docker CDN repos for that product version
  # --  Filter the applicable repo(s) for the image based on the package mappings
  # --  Calculate the desired tags for the (image, repo) pair, based on tag templates
  # --  Provide the (image, repo, tags) info in the format expected by pub
  #
  # See also: https://bugzilla.redhat.com/show_bug.cgi?id=1278668
  #
  def get_advisory_cdn_docker_file_list(advisory)
    errata = find_errata(advisory) || raise("Can't find errata '#{advisory}'")
    file_list = Hash.new { |hash, key| hash[key] = { 'docker' => {} }}

    errata.docker_file_repo_map do |mapping, docker_image, repos|
      package = docker_image.package
      repo_metadata = {}
      repos.each do |repo|
        # There can be only one variant attached to repo per product_version
        variant = mapping.product_version.variants.attached_to_cdn_repo(repo).first

        package_mapping = repo.cdn_repo_packages.where(:package_id => package).first
        tags = package_mapping.cdn_repo_package_tags.for_variant(variant).map{|tag| tag.tag_for_build(mapping.brew_build)}
        repo_metadata[repo.name] = { 'tags' => tags.sort.uniq }
      end
      file_list[mapping.brew_build.nvr]['docker'][docker_image.name] = { 'repos' => repo_metadata }
    end

    file_list
  end

  def get_ftp_paths(advisory)
    errata = find_errata(advisory)
    return { } unless errata
    return Push::Ftp.brew_ftp_map(errata)
  end
  # Takes a comma separated list of statuses, i.e. ON_QA, ON_RHNQA, and
  # returns a list of hashes. If no status is given, all valid
  # errata will be returned.
  def getRequestsByStatus(statuses, qe_owners = [])
    conditions = ['is_valid = 1']
    statuses ||= []
    qe_owners ||= []
    unless statuses.empty?
      conditions[0] += " and status in (?)"
      conditions << statuses
    end
    unless qe_owners.empty?
      users = User.find(:all, :conditions => ['login_name in  (?)', qe_owners])
      raise "Cannot find owners: #{qe_owners.join(', ')}" if users.empty?
      conditions[0] += " and assigned_to_id in (?)"
      conditions << users
    end

    errata = Errata.find(:all, :conditions => conditions, :order => 'errata_main.id', :include => [:assigned_to, :product])

    requests = []
    errata.each do |e|
      data = { :id => e.id,
        :errata_type => e.short_errata_type,
        :fulladvisory => e.fulladvisory,
        :synopsis => e.synopsis,
        :product => e.product.name,
        :contract => e.contract,
        :release_date => (e.release_date ? e.release_date.strftime("%Y-%m-%d") : ''),
        :assigned_to => e.assigned_to.login_name,
        :pkg_owner => e.package_owner.login_name,
        :status => e.status.to_s,
        :resolution => e.resolution,
        :severity => e.severity,
        :priority => e.priority
      }

      requests << data
    end

    return requests
  end

  # Updates the RHN Stage status of an advisory
  # Useful for remotely marking an advisory as on RHN Stage if
  # there is an issue pushing it wherein the errata data is not updated,
  # yet the advisory has been pushed.
  def updateWebQA(advisory, rhnqa)
    errata = find_errata(advisory)
    return 0 unless errata
    errata.rhnqa = rhnqa
    errata.save
  end

  # Returns a list of objects mapping the brew tag and build flags to
  # the brew build of an advisory
  def getErrataBrewBuilds(advisory)
    errata = find_errata(advisory)
    return [] unless errata
    builds = []
    errata.build_mappings.order('id ASC').each do |map|
      pv = map.product_version
      builds << {
        :build_tag => nil,
        :build_flags => map.flags.to_a.sort,
        :brew_build_nvr => map.brew_build.nvr,
        :product_version => {:id => pv.id, :name => pv.name},
      }
    end
    return builds
  end

  # Returns a list of ErrataStatusMetadata for all errata in the given release group.
  def getErrataStatsByGroup(group)
    return nil unless group
    release = Release.find(:first, :conditions => [ "(LOWER(name) = ? OR LOWER(description) = ?)", group.downcase, group.downcase ] )
    return nil unless release
    return getErrataStatsSummary(Errata.find(:all,
                                             :conditions => ['group_id = ?', release]))
  end

    # Returns a list of ErrataStatusMetadata for all errata of the given type (RHSA, RHBA, RHEA, security, bugfix)
  def getErrataStatsByType(type)
    return nil unless type
    type = (type.downcase == 'security' ? 'RHSA' : (type.downcase == 'bugfix' ? 'RHBA' : 'RHEA'))
    errata = Errata.find(:all, :conditions => ["errata_type in (?)", [type, Errata.add_pdc_prefix(type)]])
    return nil unless errata
    return getErrataStatsSummary(errata)
  end

  # Returns statistics for a given errata, or list of errata by their synopses.
  # If no argument is given, returns statistics for all errata.
  def getErrataStats(arg)
    results = []

    if arg
      if arg =~ /^RH(S|B|E)A-/
        conditions = [ "is_valid = 1 AND fulladvisory LIKE ?", "%#{arg}%" ];
      else
        args = arg.split(/[, ]/).map { |a| "%#{a}%" }
        cond_string = ["is_valid = 1 " ].concat( ["LOWER(synopsis) LIKE ?"] * args.length )
        conditions = [ cond_string.join(' AND '), *args ]
      end
      errata = Errata.find(:all, :conditions => conditions, :order => 'id DESC')
      return [] if errata.empty?

      if errata.length == 1
        e = errata.first
          results.<< e.fulladvisory + ': ' + e.synopsis + ', Issued ' + e.issue_date.strftime("%Y-%m-%d") + ', Updated ' + e.update_date.strftime("%Y-%m-%d")

      else
        errata.each do |e|
          results.push(e.synopsis +
                  ', Doc: '     +   (e.doc_complete ? 'Yes' : 'No')  +
                  ', QA: '    +   (e.qa_complete ? 'Yes' : 'No')   +
                  ', Files: '   +   (e.pushed ? 'Yes' : 'No')      +
                  ', RHN: '     +   (e.published ? 'Yes' : 'No')     +
                  ', Mailed: '  +   (e.mailed ? 'Yes' : 'No')      +
                  ', Status: '  +   (e.status.to_s)             +
                  ', Resolution: '+   (e.resolution ? 'Yes' : 'No'))
        end
      end
    else
      states = Hash.new(0)
      total = 0

      errata = Errata.find(:all, :conditions => "is_valid = 1 and status not in ('DROPPED_NO_SHIP')")
      errata.each do |e|
        total += 1
        states[e.status.to_s] += 1
      end

      State.open_states.each { |state|
        results.push(states[state.to_s].to_s + ' ' + state.to_s)
      }

    end

    return results
  end

  # Gets the list of files for the advisory.
  #
  # :call-seq:
  #    errata.getErrataPackages('RHSA-2009:9021')
  #    errata.getErrataPackages(4157)
  #    errata.getErrataPackages('RHSA-2009:9021', '6AS')
  #    errata.getErrataPackages('RHSA-2009:9021', '6AS', 'i386')
  #
  # Expects:
  # <tt>advisory</tt>:: The name or id of the erratum
  # <tt>release</tt>:: Optional release to restrict the search to
  # <tt>arch</tt>:: Optional arch to restrict the search to
  def getErrataPackages(advisory, release = nil, arch = nil)
    return [] unless advisory

    errata = find_errata(advisory)
    return [] unless errata

    conditions = []
    if arch
      conditions = ['errata_files.arch_id = ?', Arch.find_by_name(arch)]
    end

    filelist = []
    errata.current_files.find(:all, :conditions => conditions).each do |file|
      if release
        next unless(file.variant.rhel_variant.name == release)
      end
      filelist.push(file.devel_file)
    end

    return filelist
  end

  def getErrataPackagesRHTS(advisory)
    list = []
    return list unless advisory
    errata = find_errata(advisory)
    return list unless errata
    errata.current_files.each do |f|
      list << { :arch => f.arch.name,
        :release => f.variant.name,
        :fullpath => f.devel_file}
    end
    return list
  end

  # Deprecated
  def confirmPackage(package, md5sum, group)
    return []
  end

  # Returns a colon separated list of statistics for a given set of advisories.
  # Expects a comma separated list of advisories, ex. RHSA-2009:9021,RHBA-2009:5551
  # Returns results in the following format:
  #  fulladvisory:status:package_owner:product_name:is_embargoed
  #  ex: RHSA-2007:0912-01:UNFILED:besfahbo@redhat.com:Red Hat Enterprise Linux:0
  def getErrataSummary(conditions)
    return [] unless conditions

    args = conditions.split(/,/).map { |a| "%#{a}%" }
    cond_string = "is_valid = 1 AND " + (["fulladvisory LIKE ?"] * args.length).join(' OR ')

    errata = Errata.find(:all,
                        :conditions =>[ cond_string, *args ] ,
                        :order => 'id DESC')

    results = []
    errata.each do |e|
      embargo = (e.is_embargoed? ? '1' : '0')
      results << "#{e.fulladvisory}:#{e.status}:#{e.package_owner.login_name}:#{e.product.name}:#{embargo}"
    end

    return results
  end

  # Returns a list of ErrataActivityMetadata for advisories completed by a given quality engineer.
  # Expects:
  # <tt>login</tt>:: The e-mail address of the engineer
  # <tt>from</tt>:: Date to start the search from
  # <tt>to</tt>:: Date to end the search on
  def getErrataCompletedByLogin(login, from, to)
    results = []
    user = User.find_by_login_name(login)
    activities = user.errata_activities.find(:all,
                                             :conditions =>
                                             ["what = 'status' and added in (:states) and created_at >= :from and created_at <= :to",
                                              {:states => ['REL_PREP'],
                                                :from => from,
                                                :to => to}
                                             ])

    activities.each { |a|
      act = {
        :fulladvisory => a.errata.fulladvisory,
        :synopsis => a.errata.synopsis,
        :login_name => user.login_name,
        :activity_when => a.created_at,
        :what => a.what,
        :added => a.added
      }
      results.push act
    }
    return results
  end

  # Gets the list of rhn channels for the advisory; can be restricted by release and arch.
  #
  # :call-seq:
  #    errata.getRHNChannels('RHSA-2009:9021')
  #    errata.getRHNChannels(4157)
  #    errata.getRHNChannels('RHSA-2009:9021', '6AS')
  #    errata.getRHNChannels('RHSA-2009:9021', '6AS', 'i386')
  #
  # Expects:
  # <tt>advisory</tt>:: The name or id of the erratum
  # <tt>release_name</tt>:: Release to restrict the search to
  # <tt>arch_name</tt>:: Arch to restrict the search to
  def getRHNChannels(advisory, release_name, arch_name)
    errata = find_errata(advisory)
    return [] unless errata
    variant = Variant.find_by_name release_name
    arch = Arch.find_by_name(arch_name)
    channels = Push::Rhn.channels_for_errata(errata, variant, arch)

    if channels.empty?
      RPCLOG.warn "No channels found for #{advisory} - #{release_name} - #{arch_name}"
      return []
    end
    names = channels.collect {|c| c.name}
    names
  end

  # Get the list of bugs covered by this advisory
  # Expects - Valid errata id, either the numeric id or an advisory (2006:9012)
  # Returns - The list of bugs for the advisory
  def getBugsForErrata(advisory)
    errata = find_errata(advisory)
    bugs = []
    return bugs unless errata

    errata.bugs.each { |b| bugs << b.id }
    return bugs
  end

  def isAdvisoryFastrack(advisory)
    return Errata.find_by_advisory(advisory).release.is_fasttrack?
  end

  def get_errata_text(advisory)
    e = Errata.find_by_advisory(advisory)
    r = TextRender::ErrataRenderer.new(e, "errata/errata_text")
    r.get_text
  end

  def list_cve_errata
    errata_ids = Errata.valid_only.shipped_live.joins(:content).where("cve IS NOT NULL AND cve != ''").pluck(:id)

    # Include container errata which have CVEs in contents
    # TODO: This may fetch details from lightblue if not already
    # in database, which could be slow - any way round this?
    [LegacyErrata, PdcErrata].each do |klass|
      mapping_table = klass.build_mapping_class.table_name
      errata_ids << klass.valid_only.shipped_live.
        joins(mapping_table.to_sym).
        where("#{mapping_table}.current" => 1, "#{mapping_table}.brew_archive_type_id" => BrewArchiveType::TAR_ID).
        uniq.select(&:has_docker?).select{|e| e.container_cves.any?}.map(&:id)
    end
    errata_ids.flatten.uniq
  end

  # - advisory CVE list
  # - advisory file list (just the channel name, srpm name )
  #       [srpms even if they are not published like for extras channels]
  # For all advisories (not just RHSA) that are
  #           closed = 1
  #           valid = 1
  #           year from advisory name is > 2004
  #           status is not DROPPED
  def get_cve_info(ids)
    # TODO: Support PDC
    errata = LegacyErrata.find(ids,
                         :include => [:content])
    cve_info = []

    errata.each do |e|
      info = {:advisory => e.advisory_name, :cve_list => e.all_cves }
      cve_info << info
      srpm_channel = HashList.new
      if e.is_brew?
        e.errata_brew_mappings.each do |map|
          map.build_product_listing_iterator do |rpm,variant, brew_build, arch_list|
            next unless rpm.is_srpm?
            arch_list.each do |arch|
              chan = PrimaryChannel.find(:first, :conditions => ['arch_id = ? and variant_id = ?',
                                                                 arch,
                                                                 variant])
              srpm_channel[rpm.rpm_name] << chan.name if chan
            end
          end
        end
      else
        srpm = nil
        channels = Set.new
        e.current_files.each do |s|
          chan = PrimaryChannel.find(:first, :conditions => ['arch_id = ? and variant_id = ?',
                                                         s.arch,
                                                         s.variant])
          channels << chan.name if chan
          srpm = s if s.is_srpm?
        end
        srpm_channel[srpm.devel_file.split('/').last] = channels.to_a if srpm
      end
      info[:srpms] = srpm_channel
    end
    return cve_info
  end

  def cpe_for_channel(name)
    chan = Channel.find_by_name(name)
    raise "No such rhn channel #{name}" unless chan

    v = chan.variant
    { :cpe => v.cpe, :name => v.name, :description => v.description}
  end

  def get_live_cpe
    variants = Variant.live_variants_with_cpe
    unique_cpe = Hash.new { |hash, key| hash[key] = { }}
    variants.each do |v|
      next if unique_cpe.has_key?(v.cpe)
      unique_cpe[v.cpe][:name] = v.name
      unique_cpe[v.cpe][:description] = v.description
    end
    return unique_cpe
  end

  # For secalert use in generating cpe data
  # Returns a list of cpe mappings
  def rhsa_map_cpe(year = 2007)
    year = year.to_i
    raise "Data only valid for 2007 onward" if year < 2007
    raise "Cannot see into the future" if year > Time.now.year
    date = "#{year}-01-01"
    map = Secalert::CpeMapper.cpe_map_since date
  end

  def is_mailed(advisory)
    e = find_errata(advisory)
    e.mailed?
  end

  def set_mailed_flag(advisory, flag)
    e = find_errata(advisory)
    e.mailed = flag
    e.save
  end

  # Get some metadata of a push job.
  #
  # This call is used by pub, after a push has been triggered.  The primary
  # reason for the call is to confirm that the push should still go ahead, since
  # conditions might have changed since ET queued the pub task and a pub worker
  # picked it up.
  #
  # +task_id+   - id of the caller's pub task.
  #
  # +advisory+  - id or name of an advisory.  Optional. In current pub versions
  #               as of Jan 2016, this is not used, since each task only
  #               processes one advisory.  Later versions of pub will start to
  #               process multiple errata from a single task and will pass
  #               advisory to find the correct job.
  #
  # Return value is a hash with elements:
  #
  #  +target+   - name of the push target in pub.  (Push will abort if this does
  #               not match pub's own idea of the push target for this task.)
  #
  #  +can+      - boolean, whether ET wants to permit the push to continue.
  #
  #  +blockers+ - string array; if +can+ is false, then the reasons why the push
  #               should not continue.
  #
  def get_push_info(task_id, advisory=nil)
    params_str = "pub task #{task_id}"
    jobs = PushJob.where(:pub_task_id => task_id)

    if advisory
      params_str += ", advisory #{advisory}"
      errata = find_errata(advisory) || raise(ArgumentError, "Can't find errata '#{advisory}'")
      jobs = jobs.where(:errata_id => errata.id)
    end

    jobs = jobs.limit(2)
    if jobs.length > 1
      raise ArgumentError, "Multiple push jobs matching #{params_str}"
    elsif jobs.empty?
      raise ArgumentError, "Cannot find a push job with #{params_str}"
    end

    jobs.first.push_details
  end

  private

  def cdn_rpm_repo_map(errata, use_shadow, &block)
    Push::Cdn.rpm_repo_map(errata, map_opts(errata, use_shadow), &block)
  end

  def cdn_file_repo_map(errata, use_shadow, &block)
    Push::Cdn.file_repo_map(errata, map_opts(errata, use_shadow), &block)
  end

  def map_opts(errata, use_shadow)
    {:shadow => use_shadow}
  end

  def get_repo_names(repos, mapped_repos, use_shadow)
    out = !repos.try(:to_a) ? [] : repos.map(&:name)
    out.concat(mapped_repos.map(&:name))
    out.map!{|n| "shadow-#{n}"} if use_shadow
    out
  end

  #
  # helper method for :get_advisory_list which puzzles together
  # conditions based on parameter values for the advisory query.
  #
  # can raise StandardError if queried items are not found or invalid
  # can raise ArgumentError if passed query dates are invalid
  #
  # TODO: Support PDC
  def get_advisory_list_conditions(params)
    include = [:product]
    include.concat([:bugs, :reporter]) if params['report']

    conditions = [['is_valid = 1'], []]
    if params['group'] || params['release']
      rel_name = params['group'] || params['release']
      conditions[0] << 'group_id = ?'
      rel = Release.find_by_name(rel_name)
      raise StandardError.new("Release not valid: #{rel_name}") unless rel
      conditions[1] << rel
    end

    if (product_names = Array.wrap(params['product'])).any?
      product_names.each { |product|
        unless Product.exists?(:short_name => product)
          raise StandardError.new("Product does not exist: #{product.inspect}")
        end
      }
      products = Product.find(:all, :conditions => ['short_name in (?)', product_names] )
      conditions[0] << 'product_id in (?)'
      conditions[1] << products
    end
    if params['product_version'].present?
      pv_names = Array.wrap(params['product_version'])
      pv = pv_names.map do |name|
        ProductVersion.find_by_name(name).tap do |out|
          raise StandardError.new("Product version does not exist: #{name}") unless out
        end
      end
      include << :errata_brew_mappings
      conditions[0] << 'errata_brew_mappings.product_version_id in (?)'
      conditions[1] << pv.map(&:id)
    end
    if params['synopsis']
      conditions[0] << "synopsis like ?"
      conditions[1] << "%#{params['synopsis']}%"
    end
    if params['errata_type']
      raise StandardError.new("errata_type is not valid: #{params['errata_type']}") unless ['RHSA','RHBA','RHEA'].include? params['errata_type']
      conditions[0] << "errata_main.errata_type in (?)"
      conditions[1] << [params['errata_type'], Errata.add_pdc_prefix(params['errata_type'])]
    end
    if params['statuses']
      params['statuses'].each { |status|
        unless State.all_states.include?(status)
          raise StandardError.new("status is not valid: #{status.inspect}")
        end
      }
      conditions[0] << "errata_main.status in (?)"
      conditions[1] << params['statuses']
    end
    if params['qe_owner']
      conditions[0] << "errata_main.assigned_to_id = ?"
      assigned_to = User.find_by_login_name(params['qe_owner'])
      raise StandardError.new("Cannot find user: #{params['qe_owner']}") unless assigned_to
      conditions[1] << assigned_to
    end
    if params['qe_group']
      conditions[0] << "errata_main.quality_responsibility_id = ?"
      qe_group = QualityResponsibility.find_by_name(params['qe_group'])
      raise StandardError.new("Cannot find qe group: #{params['qe_group']}") unless qe_group
      conditions[1] << qe_group
    end
    if params['pkg_owner']
      conditions[0] << "errata_main.package_owner_id = ?"
      pkg_owner = User.find_by_login_name(params['pkg_owner'])
      raise StandardError.new("Cannot find user: #{params['pkg_owner']}") unless pkg_owner
      conditions[1] << pkg_owner
    end
    if params['bugs']
      conditions[0] << "filed_bugs.bug_id in (?)"
      include << :filed_bugs
      conditions[1] << params['bugs']
    end
    if params['package']
      conditions[0] << "packages.id = ?"
      package = Package.find_by_name(params['package'])
      raise StandardError.new("Cannot find package: #{params['package']}") unless package
      include << :packages
      conditions[1] << package
    end
    if params['created_at']
      conditions[0] << "errata_main.created_at > ?"
      conditions[1] << params['created_at'].to_time
    end
    if params['updated_at']
      conditions[0] << "errata_main.updated_at > ?"
      conditions[1] << params['updated_at'].to_time
    end
    if params['issue_date_gt']
      conditions[0] << "errata_main.issue_date > ?"
      conditions[1] << params['issue_date_gt'].to_time
    end
    if params['issue_date_lte']
      conditions[0] << "errata_main.issue_date <= ?"
      conditions[1] << params['issue_date_lte'].to_time
    end
    if params['update_date_gt']
      conditions[0] << "errata_main.update_date > ?"
      conditions[1] << params['update_date_gt'].to_time
    end
    if params['update_date_lte']
      conditions[0] << "errata_main.update_date <= ?"
      conditions[1] << params['update_date_lte'].to_time
    end

    where = [conditions[0].join(' and ')]
    where.concat(conditions[1])
    return {:conditions => where, :include => include}
  end

  def find_errata(advisory)
    begin
      return Errata.find_by_advisory(advisory)
    rescue => e
      Rails.logger.warn "Error finding #{advisory}"
      Rails.logger.warn e.message
      return nil
    end
  end

  def getErrataStatsSummary(erratas)
    results,statuses,doc_approve,doc_disapprove,total = [],Hash.new(0),0,0,0
    erratas.each { |errata|
      if errata.is_valid == 1
        statuses[errata.status] += 1
        if errata.doc_complete == 1
          doc_approve += 1
        else
          doc_disapprove += 1
        end
      end
    }
    results << { :status => 'DOC_APPROVE', :count => doc_approve}
    results << { :status => 'DOC_DISAPPROVE', :count => doc_disapprove}
    statuses.each do |status, count|
      results << { :status => status.to_s, :count => count}
      total += count
    end
    results << { :status => "TOTAL", :count => total}
    return results
  end

  def rpm_channel_mapping(errata, opts={}, &block)
    file_channel_mapping(errata, opts.merge(:method => :rpm_channel_map), &block)
  end

  # Maps files to channels
  def file_channel_mapping(errata, opts={}, &block)
    if opts[:shadow] && !errata.release.allow_shadow?
      raise "Release #{errata.release.name} for errata #{errata.advisory_name} does not support shadow channels"
    end
    # :ignore_srpm_exclusion is useless but harmless if not actually
    # listing RPMs
    opts = opts.merge(:ignore_srpm_exclusion => true)
    method = opts.fetch(:method, :file_channel_map)
    Push::Rhn.send(method, errata, opts, &block)
  end
end

class CheckSumList < Hash
  def initialize
    @methods = { "md5" => 'md5sum', "sha256" => 'sha256sum' }
    super{|hash,key| hash[key] = Hash.new}
  end

  def <<(rpm)
    @methods.each_pair do |type, method|
      next unless rpm.respond_to?(method) && (checksum = rpm.send(method)).present?
      self[type][rpm.rpm_name] ||= checksum
    end
    self
  end
end
