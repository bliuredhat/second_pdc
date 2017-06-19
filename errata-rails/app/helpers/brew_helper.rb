module BrewHelper
  # compare for brew content types for display sort:
  # RPMs first, everything else alphabetically.
  def brew_file_type_cmp(a,b)
    return  0 if a == b
    return -1 if a == 'rpm'
    return  1 if b == 'rpm'
    return  a <=> b
  end

  def brew_file_meta_headers
    title = 'Title'

    if @errata.filelist_unlocked?
      title = [title, th_actions(
        'Edit all', 'et_edit_all_title()',
        'Cancel all', 'et_cancel_all_title()'
      )].join('<br/>').html_safe
    end

    [
      title,
      'File',
      'Type'
    ]
  end

  def brew_file_meta_row(meta)
    {
      :options => {
        :'data-brew-file' => meta.brew_file_id,
        :'data-original-rank' => meta.rank || '',
        :extra_class => 'meta-rank sort-handle',

        # bz_rows wants to use the primary key to generate the ID, but
        # we often display meta not yet persisted and hence with no
        # ID.
        #
        # Use the brew file ID instead.
        #
        # Sortable table _requires_ each row to have a proper, unique
        # ID, but we don't actually use the value.
        :id => "meta-for-file-#{meta.brew_file_id}",
      },
      :content => [
        render('brew_file_meta_inline_edit_title', :meta => meta),
        brew_file_link(meta.brew_file, :brief => true),
        brew_file_type_display(meta.brew_file),
      ]
    }
  end

  # Given a collection of mappings, which should be all the mappings
  # associated with an errata & product version, returns a list of
  # actions (e.g. links) which should be presented to the user.
  #
  # Note that for PDC advisories, mappings is actually a list of
  # PdcErrataReleaseBuild records rather than a list of ErrataBrewMapping
  # records.
  #
  def build_actions(mappings)
    return [] if mappings.empty?

    unlocked = mappings.first.errata.filelist_unlocked?
    # Provide links for setting/unsetting the buildroot-push flag.
    # Since that's the only permitted flag right now, we just provide
    # these links rather than having a generic flag set/unset UI.
    rpm_mapping = mappings.find{|m| m.brew_archive_type_id.nil? }
    buildroot_push = rpm_mapping && rpm_mapping.flags.include?('buildroot-push')
    if rpm_mapping && rpm_mapping.errata.allow_edit?
      allow_request_buildroot_push = !buildroot_push &&
                                     current_user.can_request_buildroot_push? &&
                                     rpm_mapping.product_version.allow_buildroot_push?
      allow_cancel_buildroot_push = buildroot_push && current_user.can_cancel_buildroot_push?
    end

    flag = mappings.first.errata.is_pdc? ? 'PDC' : 'Compose'
    reload_files_msg = "This is for cases where the #{flag} data generated the incorrect file list for this build. Are you sure?"

    [
      (post_link_confirm("Remove this build from errata", :remove_build, mappings.first) if unlocked),

      (post_link_confirm("Reload files for this build", :reload_build, mappings.first, reload_files_msg) if unlocked),

      (post_link_confirm("Reselect file types for this build", :reselect_build, mappings.first) if unlocked && mappings.first.brew_build.has_nonrpm?),

      (post_link_confirm("Cancel Push to Buildroot", :cancel_buildroot_push, rpm_mapping, <<-'eos') if allow_cancel_buildroot_push),
Cancel a request to push this build to Brew buildroots for testing.

NOTE: this will not undo any push to buildroots which has already completed.
If you need to revert a buildroot push, please file a ticket with release engineering.

Are you sure?
eos

      (post_link_confirm("Request Push to Buildroot", :request_buildroot_push, rpm_mapping, <<-'eos') if allow_request_buildroot_push),
Request this build to be pushed to Brew buildroots now.

This option may be used to tag a build into buildroots earlier than usual.
This is most useful for core packages such as glibc and gcc which affect
the building of other packages in the product.

Are you sure?
eos
    ].compact
  end

  # These helpers relate to the labels displayed alongside builds in
  # the build list, including the builds' flags and signed/unsigned
  # status
  BUILD_LABEL_CLASSES = {
    'signed' => 'success',
    'unsigned' => 'warning',
  }
  BUILD_LABEL_HELP = {
    'signed' => 'All RPMs in this build are signed',
    'unsigned' => 'Some RPMs in this build are not signed',
    'buildroot-push' => 'A request has been made to tag this build into buildroots',
  }
  def build_label(text)
    klass = BUILD_LABEL_CLASSES[text] || 'info'
    help = BUILD_LABEL_HELP[text]
    content_tag(:span, text, :class => "label label-#{klass}", :title => help)
  end

  def build_relation_badge(rel)
    return '' if rel.blank?
    content_tag(:span, rel.slug, :class => 'label label-info pull-right',
      :title => rel.explanation)
  end

  def missing_listing_badge(id, listing_is_valid = true)
    return '' if listing_is_valid
    content_tag(:span, content_tag(:i, "Missing Product Listings"), :class => "label label-warning big", :id => id)
  end

  def check_type_present?(current_types, type)
    return false if !current_types # set preview default checkbox values
    current_types.include?( type.downcase )
  end
end
