module ErrataDetailsView
  def within_tabbar
    within('#eso-content div.eso-tab-bar') { yield }
  end

  def within_tab_content
    within('#eso-content div.eso-tab-content') { yield }
  end

  def advisory_tab(tab, advisory:)
    case tab
    when 'Summary' then "/advisory/#{advisory.id}"
    when 'Details' then "/errata/details/#{advisory.id}"
    when 'Builds'  then "/advisory/#{advisory.id}/builds"
    when 'Content' then "/errata/content/#{advisory.id}"
    end
  end

  def active_product_versions_displayed
    within_tab_content do
      find_all('form > div > h3').map(&:text)
    end
  end
  alias active_pdc_releases_displayed active_product_versions_displayed

  def inactive_product_versions_displayed
    within_tab_content do
      find_all('form > div.section_container > div.section_content > ul > li').map(&:text)
    end
  end

  alias inactive_pdc_releases_displayed inactive_product_versions_displayed
end

module PdcAdvisoryUtils
  def pdc_advisory(advisory)
    advisory = Errata.find_by_advisory(advisory)
    assert advisory.is_pdc? , "#{advisory} is not PDC"
    advisory
  end

  def pdc_releases_for_advisory(advisory)
    assert advisory.is_pdc? , "#{advisory} is not PDC"
    advisory.release.pdc_releases.partition(&:active)
  end
end
