# DelayedJob for pushing xml to secalert
require 'builder'
module Push
  class ErrataXmlJob
    include ApplicationHelper
    def initialize(errata_id)
      @errata_id = errata_id
    end
    
    def self.enqueue(errata)
      return unless errata.is_security_related? && errata.shipped_live?
      Delayed::Job.enqueue self.new(errata.id), 2
    end

    def perform
      @errata = Errata.find @errata_id
      return unless @errata.is_security_related? && @errata.shipped_live?

      xml = ::Builder::XmlMarkup.new(:indent => 2)
      template = Rails.root.join('app/views/errata/other_xml.xml.builder').to_s
      xml_text = instance_eval File.read(template), template, 1

      Secalert::Xmlrpc.send_to_secalert('secalert_xml') do |rpc|
        rpc.call('errata.savexml', @errata.advisory_name, xml_text)
      end
    end
  end
end
