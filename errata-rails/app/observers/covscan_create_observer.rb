#
# This will create a coverity scan if required when a
# build mapping gets created.
#
class CovscanCreateObserver < ActiveRecord::Observer
  observe ErrataBrewMapping, PdcErrataReleaseBuild

  def after_create(mapping)
    CovscanCreateObserver.create_covscan_run_maybe(mapping)
  end

  def self.create_covscan_run_maybe(mapping)
    errata = mapping.errata
    return nil unless errata.requires_external_test?(:covscan)

    # Will create the test run record first so that we have a run id to pass to Covscan
    new_test_run = errata.create_external_test_run_for(:covscan,
                                                       :brew_build_id=>mapping.brew_build.id)

    # Prepare some data for the xmlrpc call.
    # 'target' is the nvr to be scanned.
    # 'base' is the nvr of the previously released package. It will be
    # scanned as the 'base scan' for comparison with the new one.
    scan_request_data = {
      'target'        => mapping.brew_build.nvr,
      'base'          => ReleasedPackage.get_previously_released_nvr(mapping),
      'rhel_version'  => mapping.rhel_release_name,
      'release'       => errata.release.name,
      'package_owner' => errata.package_owner.short_name,
      'id'            => new_test_run.id,
      'errata_id'     => errata.id,
    }

    create_covscan_run(new_test_run, scan_request_data)
  end

  # Sends a message to the Covscan server requesting a scan
  # Updates the test run with the result reported by Covscan
  #
  # @param new_test_run [ExternalTestRun]
  # @param scan_request_data [Hash]
  # @return [ExternalTestRun]
  def self.create_covscan_run(new_test_run, scan_request_data)
    begin
      # Create the scan
      covscan_client = XMLRPC::CovscanClient.instance(:debug => Rails.env.development?, :verbose => Settings.verbose_curl_logging)
      response = covscan_client.create_errata_diff_scan(scan_request_data)
        case response['status']
        when 'OK'
          # Scan was created and we know the external scan id, so record it.
          # Set status to PENDING. Covscan will notify actual status changes via message bus.
          # (Actually its default value is PENDING anyway, but let's set it explicitly).
          new_test_run.update_attributes({
            :external_id => response['id'],
            :status => 'PENDING',
          })

        when 'INELIGIBLE'
          # The NVR is not eligible for a scan but covscan still creates a scan id anyway.
          # This allows covscan to reconsider the eligiblility criteria later if required.
          # Set status to INELIGIBLE. Leave it active since INELIGIBLE is considered to be a
          # passing condition similar to WAIVED or PASSED.
          message = response['message'] || 'Not eligible for scan'
          new_test_run.update_attributes({
            :external_id => response['id'],
            :status => 'INELIGIBLE',
            :external_message => message,
          })

        else
          # Parsed the XML okay but didn't get a good response.
          # Update the test run record to indicate there was a problem.
          message = response['message'] || 'Bad response from Covscan'
          new_test_run.update_attributes({
            :status => 'ERROR',
            :external_message => message,
          })

        end

      # The XMLRPC::KerberosClient will rescue all kinds of exceptions
      # and turn them into a ResponseNotOkay exception.
      # Make sure a covscan failure doesn't prevent builds from being added.
      rescue XMLRPC::KerberosClient::ResponseNotOkay => e
        new_test_run.update_attributes({
          # (Trim message in case it is very long)
          :status => 'ERROR',
          :external_message => "Covscan XMLRPC error: #{e.message[0...120]}#{'...' if e.message.length > 120}",
        })
    end
    new_test_run
  end

  #
  # This doesn't belong here really but it's related to the covscan api
  # so let's put it together with create_covscan_run_maybe above.
  #
  # Currently this is not exposed via the UI. Maybe later it will
  # be, but for now it is just for running in console in case
  # we miss some qpid messages from Covscan and need to re-sync.
  #
  def self.update_covscan_test_run_state(external_test_run)
    # Can't do anything if there's no external scan id
    return unless external_test_run.external_id

    covscan_client = XMLRPC::CovscanClient.instance(:debug=>Rails.env.development?, :verbose=>Settings.verbose_curl_logging)
    response = covscan_client.get_scan_state(external_test_run.external_id)
    case response['status']
    when 'OK'
      external_test_run.covscan_status_update(response['state'])

    when 'INELIGIBLE'
      # Need a special case to deal with INELIGIBLE scans since they seem to (incorrectly?) return the
      # same response they would for a create_errata_diff_scan rather than a normal get_scan_state response.
      external_test_run.covscan_status_update('INELIGIBLE')
      external_test_run.update_attributes(:external_message => response['message'])

    when 'ERROR'
      raise CovscanError.new(response['message'])
    else
      raise "Unexpected response status: #{response['status']} - #{response['message']}"
    end
  end
end
