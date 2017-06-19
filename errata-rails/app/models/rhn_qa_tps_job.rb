class RhnQaTpsJob < TpsJob
  include RhnTps

  def rhnqa?
    true
  end
end
