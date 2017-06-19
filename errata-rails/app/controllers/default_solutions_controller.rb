class DefaultSolutionsController < ApplicationController
  include ManageUICommon
  respond_to :html

  before_filter :find_default_solutions, :only => :index
  before_filter :find_default_solution, :except => :index

  def edit
  end

  def update
    log_attr_changes(@default_solution) do |ds|
      ds.update_attributes(params[:default_solution].slice(:text, :active))
    end
    redirect_to @default_solution
  end

  private

  def find_default_solutions
    @default_solutions = DefaultSolution.all
  end

  def find_default_solution
    @default_solution = DefaultSolution.find(params[:id])
  end

end
