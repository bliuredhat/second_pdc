# Use as a before filter in any controller expecting to look up
# a product by its short name.
class ProductShortNameFilter
  def self.before(controller)
    params = controller.params
    id = params[:product_id]
    id ||= params[:short_name]
    id ||= params[:id]

    begin
      raise "No parameter to identify product" unless id
      if id.match(/^[0-9]+$/)
        prod = Product.send(:find, id)
      else
        prod = Product.send(:find_by_short_name!, id)
      end
      controller.instance_variable_set('@product', prod)
    rescue => e
      return controller.send(:redirect_to_error!, e.message)
    end
    true
  end
end
