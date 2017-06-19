class TextOnlyAdvisoryGuard < StateTransitionGuard
  def transition_ok?(errata)
    return true unless errata.text_only?
    return true unless errata.product.text_only_advisories_require_dists?
    return errata.text_only_channel_list.get_all_channel_and_cdn_repos.any?
  end

  def ok_message(errata=nil)
    if !errata || (
         errata.text_only? &&
         errata.product.text_only_advisories_require_dists? &&
         errata.text_only_channel_list.get_all_channel_and_cdn_repos.any?
       )
      "RHN Channel/CDN Repo has been set"
    end
  end

  def failure_message(errata=nil)
    "Must set at least one RHN Channel or CDN repo"
  end

  def test_type
    'mandatory'
  end
end
