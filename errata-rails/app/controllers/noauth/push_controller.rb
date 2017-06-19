class Noauth::PushController < Noauth::ControllerBase
  include AdvisoryFinder
  verify :method => :get
  before_filter :find_errata

  def get_ftp_paths
    @map = Push::Ftp.brew_ftp_map(@errata)
    respond_to do |format|
      format.html
      format.xml { render :layout => false}
      format.json do
        render :layout => false,
        :json => @map.to_json
      end
    end
  end

  def last_successful_stage_push
    job = RhnStagePushJob.last_successful_push(@errata)
    time = job ? job.updated_at.to_i : 0
    render :text => time, :status => :ok
  end
end
