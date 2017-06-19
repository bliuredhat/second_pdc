require 'test_helper'

class TpsJobTest < ActiveSupport::TestCase

  setup do
    # Errata.qe.first
    @advisory = Errata.find(11065)
    @tps_run = @advisory.tps_run
    @arch = Arch.find_by_name('i386')
    @variant = Variant.find_by_name('5Server')
    @channel = Channel.first
    @cdnrepo = CdnBinaryRepo.first
  end

  def tps_job_factory(klass, params={})
    params.merge!(
      :run => @tps_run,
      :arch => @arch,
      :variant => @variant
    )
    klass.new(params)
  end

  def create_and_schedule_tps_job(klass, params={})
    job = tps_job_factory(klass, params)
    job.save!
    job.reschedule!
    job
  end

  test "tps job created successfully" do
    [RhnTpsJob, RhnQaTpsJob].each do |klass|
      assert tps_job_factory(klass, :channel => @channel).save!
    end
  end

  test "successfully creates rhn tps job type from common parameters" do
    job = RhnTpsJob.new(
      :run => @tps_run,
      :arch => @arch,
      :dist_source => @channel,
      :variant => @variant)

    assert job.valid?
    assert job.channel.present?
    assert_nil job.cdn_repo
    assert_instance_of RhnTpsJob, job
  end

  test "successfully creates cdn tps job from common parameters" do
    job = CdnTpsJob.new(
      :run => @tps_run,
      :arch => @arch,
      :dist_source => @cdnrepo,
      :variant => @variant)

    assert job.valid?
    assert job.cdn_repo.present?
    assert_nil job.channel
    assert_instance_of CdnTpsJob, job
  end

  test "raises error if invalid common parameters provided" do
    assert_raises(ActiveRecord::AssociationTypeMismatch) do
    CdnTpsJob.new(
      :run => @tps_run, :arch => @arch, :dist_source => @channel, :variant => @variant)
    end
  end

  test "cdn tps job validates false if no cdn repository is given" do
    refute tps_job_factory(CdnTpsJob).valid?
  end

  test "cdn tps job validates with cdn repository" do
    assert tps_job_factory(CdnTpsJob, :cdn_repo => @cdnrepo).valid?
  end

  test "cdn tps job does not validate with given channel" do
    refute tps_job_factory(CdnTpsJob,
                           :channel => @channel,
                           :cdn_repo => @cdnrepo).valid?
  end

  test "rhn tps job validates with channel" do
    assert tps_job_factory(RhnTpsJob, :channel => @channel).valid?
  end

  test "rhn tps job validates false if no channel is given" do
    refute tps_job_factory(RhnTpsJob, :cdn_repo => @cdnrepo).valid?
  end

  test "distqa jobs are scheduled without any delay by default" do
    rhnqa = create_and_schedule_tps_job(RhnQaTpsJob, :channel => @channel)
    cdnqa = create_and_schedule_tps_job(CdnQaTpsJob, :cdn_repo => @cdnrepo)

    [rhnqa, cdnqa].each do |j|
      assert_in_delta Time.now, j.started, 1.minute
    end
  end

  test "distqa jobs are scheduled without any delay if advisory is text only" do
    @advisory.update_attribute(:text_only, true)

    rhnqa = create_and_schedule_tps_job(RhnQaTpsJob, :channel => @channel)
    cdnqa = create_and_schedule_tps_job(CdnQaTpsJob, :cdn_repo => @cdnrepo)

    [rhnqa, cdnqa].each do |j|
      assert_in_delta Time.now, j.started, 1.minute
    end
  end

  test "normal tps jobs use current time as start time" do
    job = create_and_schedule_tps_job(RhnTpsJob, :channel => @channel)

    assert_in_delta Time.now, job.started, 1.minute
  end

  test "to_hash includes config key if cdn is enabled" do
    job = RhnTpsJob.with_states(TpsState::GOOD).last
    Settings.stubs(:enable_tps_cdn).returns(false)

    assert job.to_hash[:config].nil?
    refute job.to_hash.has_key?(:config)

    Settings.stubs(:enable_tps_cdn).returns(true)
    assert job.to_hash.has_key?(:config)
    assert_equal job.config, job.to_hash[:config]
  end

  #
  # The concerns of TpsJob should provide the same methods.
  #
  test "ensure interface" do
    assert_equal RhnTps.instance_methods, CdnTps.instance_methods
  end

  def get_invalid_tps_job
    TpsJob.last.tap do |tps_job|
      # TpsJob validates_presence_of variant so this will prevent saving
      tps_job.variant = nil
    end
  end

  test "reschedule will not fail silently if tps job not valid" do
    tps_job = get_invalid_tps_job
    assert_raise (ActiveRecord::RecordInvalid) { tps_job.reschedule! }
  end

  test "update job will not fail silently if tps job is not valid" do
    tps_job = get_invalid_tps_job
    assert_raise (ActiveRecord::RecordInvalid) { tps_job.run.update_job(tps_job, TpsState.find(TpsState::WAIVED), nil, nil) }
  end

  test "ensure tps jobs variant are come from the product versions of the advisory" do
    # Pick a z-stream release erratum
    z_stream_erratum = Errata.find(19829)
    applicable_product_versions = z_stream_erratum.product_versions.sort
    # Schedule TPS jobs for this erratum
    tps_run = TpsRun.create!(:errata => z_stream_erratum)
    tps_jobs_product_versions = tps_run.tps_jobs.map(&:variant).map(&:product_version).uniq.sort
    assert_equal applicable_product_versions, tps_jobs_product_versions, "TPS jobs contain unexpected product version/s."
  end
end
