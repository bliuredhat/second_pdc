Given(/^I am on "([^"]*)" page$/) do |page_name|
  visit path_for_page(page_name)
end

def path_for_page(page)
  case page
  when 'Assisted Create' then errata_new_qu_path
  when 'PDC Assisted Create' then errata_new_qu_pdc_path
  when 'New Advisory' then advisory_new_path
  when 'CPE Management' then '/security/cpe_management'
  else
    raise "No path found for page: #{page}"
  end
end
