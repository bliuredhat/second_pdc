class BadErrataID < RuntimeError

  def initialize(bad_id)
    if bad_id
      @message = "Bad errata id given: " + bad_id
    else
      @message = "No errata id given."
    end
  end

  def to_s
    return @message
  end

end
