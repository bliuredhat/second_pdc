class BatchesController < ApplicationController
  include ManageUICommon

  before_filter :batch_admin_restricted, :only => [:create, :edit, :new, :update]
  before_filter :set_supported_releases, :only => [:create, :edit, :new, :update]
  before_filter :set_index_nav, :only => [:index, :released_batches]
  before_filter :find_batch, :only => [:edit, :show, :update]
  before_filter :batch_editable, :only => [:edit, :update]

  # JSON API is in Api::V1::BatchesController
  respond_to :html

  def create
    @batch = Batch.new(params[:batch])
    if @batch.save
      flash_message :notice, 'Batch was successfully created.'
      redirect_to :action => :show, :id => @batch
    else
      render :action => :new
    end
  end

  def edit
    extra_javascript %w[change_alert_modal]
    set_page_title "Edit Batch '#{@batch.name}'"
  end

  def index
    @batches = Batch.unreleased
    respond_with(@batches)
  end

  def released_batches
    @batches = Batch.released
    respond_with(@batches)
  end

  def new
    set_page_title 'New Batch'
    @batch = Batch.new
  end

  def show
    @errata = @batch.errata
    set_page_title "Batch '#{@batch.name}'"
  end

  def update
    @batch.update_attributes(params[:batch])
    if @batch.valid?
      flash_message :notice, 'Batch was successfully updated.'
      flash_message :alert, 'Batch is inactive but contains active advisories' \
        if !@batch.is_active? && @batch.errata.active.any?

      redirect_to :action => 'show', :id => @batch
    else
      flash_message :error, "Unable to update: #{@batch.errors.full_messages.join(',')}"
      render :action => 'edit'
    end
  end

  private

  def get_secondary_nav
    return [
      { :name => 'Unreleased Batches', :controller => :batches, :action => :index },
      { :name => 'Released Batches',   :controller => :batches, :action => :released_batches }
    ]
  end

  def set_supported_releases
    @supported_releases = Release.batching_enabled
  end

  #
  # Override from ManageUICommon, as a slightly
  # different set of roles may manage batches
  #
  def can_edit_mgmt_items?
    return false if @batch.try(:is_released?)
    current_user.can_manage_batches?
  end

  def find_batch
    @batch = Batch.find(params[:id])
  end

  def batch_editable
    if @batch.is_released?
      flash_message :alert, 'Batch cannot be edited, as it has been released'
      redirect_to :action => :show, :id => @batch
      return false
    end
    true
  end
end

