class BuildCommentObserver < ErrataBuildMappingObserver
  observe ErrataBrewMapping, PdcErrataReleaseBuild

  def after_save(m)
    saved_mappings << m
  end

  def after_rollback(*args)
    saved_mappings.clear
  end

  def after_commit(*args)
    obsoleted_mappings = saved_mappings.select{|m| obsoleted?(m)}
    saved_mappings.clear
    return if obsoleted_mappings.empty?

    obsoleted_mappings.group_by(&:errata).each do |errata,mappings|
      add_build_removal_comment(errata,mappings)
    end
  end

  def add_build_removal_comment(errata, mappings)
    texts = []

    mappings.group_by{|m| [m.brew_build,m.pv_or_pr]}.each do |(build,pv_or_pr),build_mappings|
      text = generate_basic_text(errata, pv_or_pr, build, build_mappings)
      text = "#{text} (for #{pv_or_pr.short_name})"
      texts << text
    end

    comment_text = if texts.length == 1
      "Removed #{texts.first} from advisory."
    else
      "Removed from advisory:\n  #{texts.join("\n  ")}"
    end
    errata.comments.create(:text => comment_text)
  end

  private
  def saved_mappings
    Thread.current[:build_comment_observer_saved_mappings] ||= []
  end

  def generate_basic_text(errata, pv_or_pr, build, build_mappings)
    can_get_removed_types = false
    if pv_or_pr.instance_of? ProductVersion
      # were all types of files removed, or just some?
      if errata.errata_brew_mappings.where(:product_version_id => pv_or_pr).pluck(:brew_build_id).include?(build.id)
        can_get_removed_types = true
      end
    elsif pv_or_pr.instance_of? PdcRelease
      if errata.pdc_errata_release_builds.where(:pdc_errata_release_id => pv_or_pr).
        pluck(:brew_build_id).include?(build.id)
        can_get_removed_types = true
      end
    end

    if can_get_removed_types
      removed_types = build_mappings.map{|m| m.brew_archive_type.try(:name) || 'RPM'}.sort
      "#{removed_types.join(', ')} files of build #{build.nvr}"
    else
      "build #{build.nvr}"
    end
  end
end
