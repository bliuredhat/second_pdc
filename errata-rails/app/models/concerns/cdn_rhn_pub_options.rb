# This module encapsulates the pub options common to all RHN & CDN stage &
# live push targets.
module CdnRhnPubOptions
  extend ActiveSupport::Concern

  included do
    self::PUB_OPTIONS = {
      'push_files' => {
        :default     => true,
        :description => 'Upload errata files',
      },

      'push_metadata' => {
        :default     => true,
        :description => 'Push metadata',
      },
    }
  end

  def valid_pub_options
    self.class::PUB_OPTIONS
  end
end
