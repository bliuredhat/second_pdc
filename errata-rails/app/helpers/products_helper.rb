module ProductsHelper
  def supports_pdc_note_text(product, is_editing)
    note_text = 'Does this product support PDC-based releases and advisories?'
    if !product.can_change_supports_pdc? && is_editing
      note_text << " (Can't change because the product has at least one active PDC release)"
    end
    note_text
  end

  def maybe_link_to_pdc_product(pdc_product)
    return 'None' if pdc_product.nil?
    link_to(pdc_product.pdc_id, pdc_product.view_url, target: '_blank')
  end
end
