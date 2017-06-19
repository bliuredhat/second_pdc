class Noauth::ProductsController < Noauth::ControllerBase
  verify :method => :get

  def rpm_prefixes
    @products = BrewRpmNamePrefix.products_with_prefixes
  end
end
