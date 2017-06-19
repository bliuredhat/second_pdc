json.attributes do
  json.extract! resource,
    :last_good_run_id,
    :brew_rpm_id,
    :package_id,
    :package_name,
    :person,
    :old_version,
    :errata_brew_mapping_id,
    :obsolete,
    :brew_build_id,
    :run_date,
    :errata_file_id,
    :errata_id,
    :overall_score,
    :package_path,
    :new_version,
    :variant,
    :errata_nr
end

json.relationships do
  json.results resource.rpmdiff_results,
    :can_approve_waiver,
    :log,
    :need_push_priv,
    :result_id,
    :score,
    :test_id
end
