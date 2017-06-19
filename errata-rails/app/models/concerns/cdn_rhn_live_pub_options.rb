# This module encapsulates the pub options common to RHN & CDN live (and not stage)
# push targets.
module CdnRhnLivePubOptions
  extend ActiveSupport::Concern

  included do
    self::PUB_OPTIONS.merge!({
      'nochannel' => {
        :description => 'Skip subscribing packages (nochannel)',
      },
    })
  end
end
