Rails.application.config.middleware.insert_before 0, "Rack::Cors" do
  allow do
    origins /\.redhat.com$/

    # can't iterate over Rails.application.routes since it isn't
    # initialised at this point in the bootup sequence

    no_auth_endpoints = %w(
      /errata/xmlrpc.cgi
      /errata/tps-xmlrpc.cgi
      /tps/tps_service
      /errata/errata_service
      /errata/get_channel_packages/*
      /errata/get_released_channel_packages/*
      /errata/get_pulp_packages/*
      /errata/get_released_pulp_packages/*
      /errata/get_released_packages/*
      /errata/get_tps_txt/*
      /errata/blocking_errata_for/*
      /errata/depending_errata_for/*
      /push/get_ftp_paths/*
      /push/last_successful_stage_push/*
      /cve/list
      /cve/show/*
      /api/v1/security/cpes.json*
    )

    no_auth_endpoints.each do |endpoint|
      resource endpoint, :headers => :any, :methods => [:get, :options]
    end
  end
end
