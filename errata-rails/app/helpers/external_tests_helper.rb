module ExternalTestsHelper
  def external_test_run_link(test_run, link_text=nil)
    if test_run.external_id.present?
      link_to link_text||test_run.run_url, test_run.run_url, :target=>'_blank'
    else
      content_tag :span, '-'
    end
  end

  def external_test_run_id_link(test_run)
    link_text = test_run.external_id.to_s
    suffix = ''

    # If a test is of a particular subtype, show it.  Helps to differentiate,
    # which is important since different subtypes can share the same ID.
    subtype = test_run.external_test_type.subname
    if link_text.present? && subtype.present?
      suffix = "(#{subtype})"
    end

    safe_join([external_test_run_link(test_run, link_text), suffix], ' ')
  end
end
