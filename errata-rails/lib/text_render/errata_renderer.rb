# http://amberbit.com/blog/render-views-partials-outside-controllers-rails-3
module TextRender
  class ErrataRenderer < AbstractController::Base
    include AbstractController::Rendering
    include AbstractController::Layouts
    include AbstractController::Helpers
    include AbstractController::Translation
    include AbstractController::AssetPaths

    #include ActionController::UrlWriter # deprecated in Rails 3
    include Rails.application.routes.url_helpers

    helper ApplicationHelper
    helper ErrataHelper
    self.view_paths = "app/views"

    def initialize(errata, template)
      @errata = errata
      @template = template
    end

    def get_text
      render :template => @template
    end
  end
end
