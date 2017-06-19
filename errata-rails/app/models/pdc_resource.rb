class PdcResource < ActiveRecord::Base

  attr_accessible :pdc_id, :type

  class << self

    def get(pdc_id)
      find_or_create_by_pdc_id(pdc_id)
    end

    def pdc_attributes(*attribute_syms)
      attribute_syms.each do |attribute_sym|
        define_method(attribute_sym) do
          pdc_record.send(attribute_sym)
        end
      end
    end
    def pdc_class
      "PDC::V1::#{pdc_class_name}".constantize
    end

    # Allow pdc class name (in the gem) which usually have a
    # 1 to 1 mapping with errata to be overridden
    # e.g.
    #   class PdcRelease < PdcResource; end
    #
    #   class PdcVariant < PdcResource
    #     pdc_class_name :ReleaseVariant
    #   end
    #
    # PdcRelease will be mapped to Release
    # PdcVariant will be mapped to ReleaseVaraint
    #
    def pdc_class_name(class_name = nil)
      @pdc_class_name ||= if class_name.present?
                            class_name
                          else
                            name.sub(/^Pdc/, '')
                          end
    end
  end


  def pdc_record
    @_pdc_record ||= self.class.pdc_class.find(self.pdc_id)
  end

  def url
    #TODO: remove this when pdc-gem implements #url
    pdc = PDC.config
    URI.join(pdc.site, pdc.api_root, pdc_record.uri).to_s
  end

  # Not sure how to derive it consistently, so this may not work
  # for all items. This definition works for PDC releases at least.
  # TODO: This should be implemented in pdc-gem also if possible
  def view_url
    URI.join(PDC.config.site, "/#{self.class.pdc_class_name.downcase}/#{pdc_id}/").to_s
  end

  def pdc_class
    self.class.pdc_class
  end

  def is_pdc?
    true
  end

end
