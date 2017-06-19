module Lightblue

  # NOTE: we don't want Lightblue::Client to be aware of LightblueConf
  # but dont want the caller to pass this as well.
  # Hence the compromise
  class ErrataClient < Client
    def initialize
      super(LightblueConf::VALUES.merge(:logger => LIGHTBLUE_LOG))
    end
  end
end
