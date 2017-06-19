require 'test_helper'

class LiveAdvisoryNameTest < ActiveSupport::TestCase
  test "basic validations" do
    la = LiveAdvisoryName.last
    new_la = LiveAdvisoryName.new(:errata => la.errata,
                              :year => la.year,
                              :live_id => la.live_id)
    refute new_la.valid?

    errata = Errata.find 11149
    assert_equal 'RHSA-2011:11149-04', errata.fulladvisory
    refute errata.has_live_id_set?

    # Jump to the future to ensure that we set live advisory for a
    # year which currently has no live advisories
    Time.stubs(:now => Time.utc('2037-01-01'))
    LiveAdvisoryName.set_live_advisory!(errata)
    assert errata.has_live_id_set?
    assert_equal "RHSA-2037:0001-04", errata.fulladvisory
  end

  test 'can assign live ID from multiple threads' do
    errata_ids   = [20836, 20291, 19829, 19828]
    year         = 2012
    new_comments = Comment.where('id > ?', Comment.pluck('max(id)').first)
    max_live_id  = LiveAdvisoryName.where(:year => year).pluck('max(live_id)').first
    new_live_ids = LiveAdvisoryName.where(:year => year).where('id > ?', max_live_id)
    live_names   = LiveAdvisoryName.where(:errata_id => errata_ids)
    fulladvisory = errata_ids.map{ |id| [id, Errata.find(id).fulladvisory] }

    # To simplify the test, these all need to be the same type and have revision of 1,
    # and currently have no live ID set
    errata = Errata.where(:id => errata_ids)
    assert_equal [1],      errata.pluck('distinct revision')
    assert_equal ['RHBA'], errata.pluck('distinct errata_type')
    assert live_names.empty?

    # Freeze time for predictable live IDs
    Time.stubs(:now => Time.utc("#{year}-01-01"))

    # In fixtures, currently this value is 3 digits.
    # It'll break the test if that changes
    assert max_live_id >= 100
    assert max_live_id <= 999

    main_consumer = Queue.new
    main_producer = Queue.new

    # Hook before create! to yield to another thread.
    #
    # The purpose is to simulate the worst-case scheduling: A thread started a
    # transaction, calculated the new live id, and is just about to create it
    # before another thread takes over.
    used_yielding_create = false
    real_create = LiveAdvisoryName.method(:create!)
    yielding_create = lambda do |*args|
      used_yielding_create = true
      Thread.pass
      real_create.call(*args)
    end

    begin
      self.class.with_replaced_method(LiveAdvisoryName, :create!, yielding_create) do
        threads = errata_ids.map do |errata_id|
          Thread.new do
            # Synchronize all threads entering set_live_advisory together
            begin
              main_consumer.push(nil)
              main_producer.pop
              LiveAdvisoryName.set_live_advisory!(Errata.find(errata_id))
            ensure
              ActiveRecord::Base.connection.close
            end
          end
        end

        # Protect test from hanging in failure case
        Timeout.timeout(5) do
          # Synchronize all threads at the beginning, then wait for them to
          # finish
          threads.each{|_| main_consumer.pop }
          threads.each{|_| main_producer.push(nil) }
          threads.each(&:join)
        end
      end

      # Now check every live ID was assigned OK
      i = 0
      new_ids_and_names = errata_ids.map do |_|
        i += 1
        live_id = max_live_id + i
        [live_id, "RHBA-#{year}:0#{live_id}-01"]
      end

      assert_equal new_ids_and_names.map(&:first), live_names.reload.map(&:live_id).sort
      assert_equal new_ids_and_names.map(&:second), Errata.where(:id => errata_ids).pluck('fulladvisory').sort

      # This is just a sanity check that our hooked create was really used, as the test may incorrectly pass if not.
      assert used_yielding_create
    ensure
      # Because we modified data from threads, which have their own
      # transactions, changes won't be implicitly rolled back.
      new_comments.delete_all
      live_names.delete_all
      fulladvisory.each do |(id, value)|
        Errata.where(:id => id).update_all(:fulladvisory => value)
      end
    end
  end

  uses_transaction 'test_can_assign_live_ID_from_multiple_threads'

  test "end to end test advisory" do
    errata = Errata.find(22001)
    assert errata.is_end_to_end_test?
    assert_equal 'RHBA-2016:22001-01', errata.fulladvisory
    refute errata.has_live_id_set?

    # There are multiple live advisories for 2011
    Time.stubs(:now => Time.utc('2011-01-01'))
    Settings.end_to_end_test_year_offset = 7000

    assert_difference('ActionMailer::Base.deliveries.length', 1) do
      LiveAdvisoryName.set_live_advisory!(errata)
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal 'LIVE-ID-CHANGE', mail['X-ErrataTool-Action'].value

    assert errata.has_live_id_set?
    assert_equal "RHBA-9011:0001-01", errata.fulladvisory
  end

end
