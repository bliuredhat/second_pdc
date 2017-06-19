class CdnQaTpsJob < TpsJob
  include CdnTps

  # Confusingly named, since this isn't actually related to RHN at all.
  # The method rhnqa? actually means dist_tps_qa? (maybe rename it some day)
  def rhnqa?
    true
  end
end
