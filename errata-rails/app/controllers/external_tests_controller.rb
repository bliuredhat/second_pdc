class ExternalTestsController < ApplicationController
  include CurrentUser

  verify :method => :post,
         :only => [:reschedule],
         :redirect_to => { :action => :list_all }

  before_filter :set_current_user_ivar

  before_filter :find_errata, :only => [:list, :show]
  before_filter :set_vars_for_run, :only => [:show, :reschedule, :refresh_test_run_status]
  before_filter :set_vars_for_test_type, :only => [:list]
  before_filter :set_index_nav, :only => [:list, :show]
  before_filter :pre_check_reschedule, :only => [:reschedule]

  def list
    @test_runs = @errata.external_test_runs_for(@test_types).order('external_test_runs.updated_at desc')
  end

  def show
  end

  def reschedule
    msg = "Scan for #{scan_for_display_name} rescheduled"
    if @test_run.type_is?(:covscan)
      @test_run.covscan_reschedule!
      flash_message :notice, msg
    elsif @test_run.type_is?(:ccat)
      @test_run.ccat_reschedule!
      flash_message :notice, msg
    end
    redirect_to :back
  end

  def list_all
    # Todo: allow filtering by status, release, etc
    @test_type = ExternalTestType.get(params[:test_type] || 'covscan')
    @test_runs = ExternalTestRun.of_type(@test_type.with_related_types).order('external_test_runs.updated_at desc').paginate(:page=>params[:page], :per_page=>200)
  end

  def refresh_test_run_status
    if @test_run.can_update_status?
      begin
        update_external_test_run(@test_run)
        flash_message :notice, "Scan for #{@test_run.name} successfully updated."
      rescue CovscanError => e
        flash_message :alert, "Error received: #{e}."
      rescue StandardError => e
        flash_message :error, "Error occurred while communicating with #{@test_run.name}."
        logger.warn "Error updating #{@test_run.name} test run: #{@test_run.inspect} #{e.message}"
      end
    else
      flash_message :error, "Can't update the status for this #{@test_run.name} test run"
    end
    redirect_to :back
  end

  private

  def scan_for_display_name
    @test_run.brew_build.present? ? @test_run.brew_build.nvr : @test_run.name
  end

  def pre_check_reschedule
    unless @test_run.reschedule_permitted?(@current_user)
      flash_message :alert, "Scan for #{scan_for_display_name} not rescheduled!"
      redirect_to :back
    end
  end

  def set_vars_for_run
    return redirect_to_error!("Missing test_run_id") unless params[:test_run_id]
    @test_run = ExternalTestRun.find(params[:test_run_id])
    @test_type = @test_run.external_test_type
    @test_types = @test_type.with_related_types
  end

  def set_vars_for_test_type
    @test_type = ExternalTestType.get(params[:test_type])
    @test_types = @test_type.with_related_types
  end

  def get_secondary_nav
    super.map do |link|
      # Default behavior is to set selected based on controller/action.
      # We need to filter based on test type as well.
      if link[:controller] == 'external_tests'
        if link[:test_type] == @test_type.try(:name)
          # So we get the right page title
          @secondary_nav_selected_name = link[:name]
        else
          # So we don't highlight the wrong tab
          link.except!(:selected)
        end
      end
      link
    end
  end

  def update_external_test_run(test_run)
    # (Covscan is currently the only external test run type. Some day there might be more).
    CovscanCreateObserver.update_covscan_test_run_state(test_run)
  end

end
