require 'test_helper'

module Api
  module V1
    class ApiControllerTest < ActiveSupport::TestCase
      class DefaultApiController < ApiController
      end

      class WithOptionsApiController < ApiController
        paginate :default => 123, :max => 456
      end

      test 'pagination is enabled by default' do
        controller = DefaultApiController.new
        assert controller.send(:page_size_default) > 0
        assert controller.send(:page_size_max)     > 0
      end

      test 'pagination options are applied' do
        controller = WithOptionsApiController.new
        assert_equal 123, controller.send(:page_size_default)
        assert_equal 456, controller.send(:page_size_max)
      end

    end
  end
end
