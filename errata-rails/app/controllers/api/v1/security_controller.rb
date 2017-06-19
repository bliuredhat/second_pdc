# :api-category: Security
class Api::V1::SecurityController < ApplicationController
  respond_to :json

  # Actions that do not require authentication
  no_auth_actions = [ :cpes ]

  before_filter :check_user_auth, :except => no_auth_actions
  before_filter :readonly_restricted, :except => no_auth_actions
  before_filter :security_restricted, :except => no_auth_actions

  #
  # Retrieve all CPEs and their associated variants. The 'live' field in the output
  # indicates whether any advisory has been shipped for that CPE and variant.
  # This API does not require authentication.
  #
  # :api-url: /api/v1/security/cpes
  # :api-method: GET
  # :api-response-example: file:publican_docs/Developer_Guide/api_examples/cpes.json
  #
  def cpes
    @variants = Variant.all.group_by{|variant| variant.cpe || ''}.sort_by{|cpe,v| cpe}
  end

  private

  def variant_is_live?(variant)
    @live_variant_ids ||= Variant.live_variant_ids
    @live_variant_ids.include?(variant.id)
  end
  helper_method :variant_is_live?
end
