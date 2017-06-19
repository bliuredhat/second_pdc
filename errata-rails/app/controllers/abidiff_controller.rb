class AbidiffController < ApplicationController
  before_filter :find_errata
  before_filter :set_index_nav
  before_filter :add_page_title
  respond_to :html, :json

  def list
    @abidiff_runs = @errata.abidiff_runs
    respond_with @abidiff_runs
  end

  private

  def add_page_title
    set_page_title "ABI Diff Runs <span class='superlight'>for #{@errata.fulladvisory}</span>".html_safe
  end
end
