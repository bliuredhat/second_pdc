# NOTE: this works around the lack of cpe information in PDC
# In the future PDC will manage CPEs for PDC Variants, see Bug 1452448
#
# TODO: delete this concern when PDC adds the support for fetching cpe list

module PdcLocalCpeList
  extend ActiveSupport::Concern

  module ClassMethods
    CPE_LIST_FILE_PATH = Rails.root.join('config', 'pdc_cpe_list.yml').freeze

    def cpe_list_hash
      # NOTE: yaml is kept in memory as a hash, so the server must be
      # restarted if the file is updated
      @cpe_list_hash ||= YAML.load_file(CPE_LIST_FILE_PATH)

    rescue => e
      Rails.logger.error "cpe list failed to load with error: #{e}"
      {}
    end
  end

  def cpe_list
    self.class.cpe_list_hash.fetch(pdc_id, [])
  end
end
