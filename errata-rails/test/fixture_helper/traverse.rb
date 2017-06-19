BrewBuild.class_eval do
  def _fixture_traverse_keys; [:brew_files, :package]; end
end

BrewFile.class_eval do
  def _fixture_traverse_keys; [:brew_archive_type]; end
end

Channel.class_eval do
  def _fixture_traverse_keys; [:product_version]; end
end

ProductVersion.class_eval do
  def _fixture_traverse_keys
    [
      :active_push_targets,
      :rhel_release,
      :variants,
    ]
  end
end

Errata.class_eval do
  def _fixture_traverse_keys
    [
      :assigned_to,
      :brew_file_meta,
      :content,
      :current_files,
      :errata_brew_mappings,
      :filed_bugs,
      :filed_jira_issues,
      :product,
      :push_jobs,
      :release,
      :reporter,
      :rpmdiff_runs,
      :state_indices,
      :text_only_channel_list,
   ]
  end
end

ErrataBrewMapping.class_eval do
  def _fixture_traverse_keys; [:errata, :brew_build, :product_version]; end
end
