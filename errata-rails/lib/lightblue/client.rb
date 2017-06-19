require 'lightblue/configuration'
require 'lightblue/http'
require 'lightblue/entity'
require 'lightblue/validations'

module Lightblue

  class Client
    include HTTP
    include Validations

    attr_accessor(*Configuration::KEYS)

    def initialize(config = {})
      config = Configuration.defaults.merge(config)
      Configuration::KEYS.each { |k| send("#{k}=", config[k]) }
      validate
    end

    def container_image
      Entity::ContainerImage.new(self)
    end

  end
end
