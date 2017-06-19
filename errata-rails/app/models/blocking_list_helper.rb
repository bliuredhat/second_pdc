module BlockingListHelper

  #
  # Just a text list of advisories.
  # Using this in a couple of dependency related
  # transition guard messages. Including the status
  # since it is useful information for resolving
  # dependency issues.
  #
  def blocking_list_helper(blocking_list, opts={})
    blocking_list.map { |errata|
      "#{errata.advisory_name}#{"/#{errata.status}" unless opts[:no_status]}"
    }.join(", ")
  end

end
