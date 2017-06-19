require 'test_helper'

class NotifierTest < ActiveSupport::TestCase
  FIXTURES_PATH = File.dirname(__FILE__) + '/../fixtures'
  CHARSET = "UTF-8"

  # include ActionMailer::Quoting
  include ApplicationHelper
  include UserHelper

  def setup
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []

    # For later when we do more fine grained testing
    # See http://izumi.plan99.net/manuals/testing_rails_applications-c17d65ba.html
    # @expected = TMail::Mail.new
    # @expected.set_content_type "text", "plain", { "charset" => CHARSET }
    # @expected.mime_version = '1.0'

    # ------------------------------------------------------------------------
    # Pick some arbitrary objects that we can use as args for testing emails
    # (There might be a better way to do this...)
    #
    @test_errata        = RHSA.last # rhba_async
    @test_comment       = Comment.find(:first, :conditions=>['text like ?', '%"%']) # want one with a double quote in it since i'm checking escaping...
    @test_user          = User.last
    @test_ftp_push_job  = FtpPushJob.last
    @test_result        = RpmdiffResult.last
    @test_release       = Release.first
    @test_text          = 'text content with some "quotes" & an ampersand'
    @test_recipient     = 'test_recipient@redhat.com'
    @test_link          = 'http://testlink.redhat.com/test?123'

    @test_role_change_message = role_change_message(
      @test_user.old_values,
      Role.where(:id => 4..11).to_a,
      Role.where(:id => 9..13).to_a,
      @test_user)

    # Uncomment this for shorter comment text
    #@test_comment.text = 'comment here'

    # For the tests to pass these need to have a info_request_target
    # and a blocking_issue_target respectively. In our fixtures this
    # is the only one with those. (Actually I had to add the
    # info_request_target into the fixture data. Not sure why most of
    # the Role records don't have these fields defined.
    # TODO: investigate why this is so.
    #
    @test_info_role     = Role.find_by_name('releng')
    @test_blocking_role = Role.find_by_name('releng')

    # TODO: Add some fixture data so we can grab a suitable
    # @test_info_request and @test_blocking_issue record from the database
    # instead of creating them here.
    #
    @test_info_request = InfoRequest.create(
      :errata => @test_errata,
      :info_role => @test_info_role,
      :who => User.last,
      :summary => 'summary here',
      :description => 'description here'
    )

    @test_blocking_issue = BlockingIssue.create(
      :errata => @test_errata,
      # This one has a blocking_issue_target which is used to get the recipient
      # TODO: this is messy, clean it up?
      :blocking_role => Role.find_by_name('releng'),
      :who => User.last,
      :summary => 'summary here',
      :description => 'description here'
    )

    @all_emails_for_test = {
      :blocking_issue                   => @test_blocking_issue,
      :info_request                     => @test_info_request,
      :bugs_updatebugstates             => @test_comment,
      :bugs_add_bugs_to_errata          => @test_comment,
      :bugs_remove_bugs_from_errata     => @test_comment,
      :docs_approve                     => @test_comment,
      :docs_disapprove                  => @test_comment,
      :docs_ready                       => @test_errata,
      :docs_update_reviewer             => [@test_errata, @test_user],
      :request_docs_approval            => @test_errata,
      :management_report                => @test_release,
      :docs_text_changed                => [@test_errata, @test_text, @test_user],
      :file_pub_failure_ticket          => [@test_ftp_push_job, @test_user],
      :sign_advisory                    => [@test_errata, @test_text, @test_recipient],
      :tps_reschedule_all               => @test_comment,
      :tps_reschedule_job               => @test_comment,
      :tps_reschedule_all_failure       => @test_comment,
      :tps_reschedule_all_rhnqa         => @test_comment,
      :tps_reschedule_all_rhnqa_failure => @test_comment,
      :tps_tps_service                  => @test_comment,
      :tps_waive                        => @test_comment,
      :tps_unwaive                      => @test_comment,
      :tps_all_jobs_finished            => @test_comment,
      :rpmdiff_add_comment              => @test_comment,
      :rpmdiff_waive                    => @test_comment,
      :rpmdiff_unwaive                  => @test_comment,
      :errata_file_request              => @test_comment,
      :errata_update                    => @test_comment,
      :errata_request_signatures        => @test_errata,
      :request_translation              => [@test_errata, @test_text],
      :request_rhnlive_push             => @test_errata,
      :request_rcm_rhsa_push            => @test_errata,
      :rhsa_shipped_live                => [@test_errata, @test_user],
      :partners_new_errata              => @test_errata,
      :partners_changed_files           => @test_errata,
      :user_roles_change                => [@test_user, @test_user, @test_role_change_message],
      :errata_build_signed              => @test_comment,
      :errata_cve_change                => @test_comment,
      :errata_live_id_change            => @test_comment,
      :errata_signatures_requested      => @test_comment,
      :errata_signatures_revoked        => @test_comment,
      :errata_state_change              => StateChangeComment.first,
      :jira_issue_added                 => @test_comment,
      :jira_issue_removed               => @test_comment,
    }

  end

  test "retries on server busy error" do
    mail = Notifier.send(:errata_update, @test_comment)

    Notifier.expects(:sleep).once
    ActionMailer::Base.expects(:deliver_mail).twice.raises(Net::SMTPServerBusy).returns(nil)
    mail.deliver
  end

  test "doesn't retry on fatal error" do
    mail = Notifier.send(:errata_update, @test_comment)

    Notifier.expects(:sleep).never
    ActionMailer::Base.expects(:deliver_mail).once.raises(Net::SMTPFatalError)

    # Possible FIXME: fatal error is not raised, which seems possibly wrong.
    mail.deliver
  end

  test "propagates non-SMTP errors" do
    mail = Notifier.send(:errata_update, @test_comment)

    Notifier.expects(:sleep).never
    ActionMailer::Base.expects(:deliver_mail).once.raises(RegexpError)

    assert_raises(RegexpError){ mail.deliver }
  end

  test "eventually gives up on repeated server busy errors" do
    mail = Notifier.send(:errata_update, @test_comment)

    attempts = 7
    Notifier.expects(:sleep).at_most(attempts-1).at_least(attempts-1)
    ActionMailer::Base.expects(:deliver_mail).at_most(attempts).at_least(attempts).raises(Net::SMTPServerBusy)
    assert_raises(Net::SMTPServerBusy){ mail.deliver }
  end

  test 'email sent to login_name' do
    assert_blank @test_user.email_address

    mail = Notifier.send(:user_roles_change, @test_user, @test_user, @test_role_change_message).deliver
    # notification sent to user.login_name when email_address is not given.
    assert_equal @test_user.login_name, mail.to.first
  end

  test 'email sent to email_address' do
    assert_blank @test_user.email_address
    expected_email = 'test_email@redhat.com'
    assert_not_equal expected_email, @test_user.login_name
    @test_user.update_attributes!(:email_address => expected_email)

    mail = Notifier.send(:user_roles_change, @test_user, @test_user, @test_role_change_message).deliver
    # notification sent to user.email_address when the email_address is specified.
    assert_equal expected_email, mail.to.first
  end

  #
  # A rough smoke test to make sure all emails can be created without
  # errors and can pass a few sanity tests.
  #
  test "can create all emails without error" do
    # Make a big hash of emails we want to test.
    # The key is the type of email and the value is the args.

    # (Sorting just so printed output looks nice. Can't sort symbols, hence stringify_keys)
    @all_emails_for_test.stringify_keys.sort.each do |type,args|

      # Uncomment this (and adjust as applicable) if you just want to look at certain emails
      #next unless type.to_s =~ /tps_/

      # Going to use splat on args. This lets us be lazy (and neat) above
      args = [args] unless args.is_a? Array

      # Deliver the email
      Notifier.send(type,*args).deliver

      # When using delivery method :test ActionMailer puts emails in here,
      # so the last one should be the one we just delivered.
      mail = ActionMailer::Base.deliveries.last

      # Some sanity checks
      assert mail, "#{type} returned nil or failed"
      assert_equal Mail::Message, mail.class, "#{type} returned an unexpected class"

      # At least one recipient?
      assert mail.to.present? && !mail.to.empty?, "#{type} has no recipients"

      # Subject and body present?
      assert mail.subject.present?, "#{type} has no subject"
      assert mail.body.present?, "#{type} has no body"

      # Content type okay?
      assert_equal "text/plain; charset=UTF-8", mail.content_type, "#{type} has bad content type"
      assert_equal CHARSET, mail.charset,      "#{type} has bad charset"

      # Who header present?
      if args == [@test_comment]
        assert_equal @test_comment.who.login_name, mail.header['X-ErrataTool-Who'].value
      end

      # The layout was included? (check for the little footer)
      expected_footer_text = "(ET #{SystemVersion::VERSION} errata-test.example.com test)"
      if type =~ /partners_/
        # Should NOT have the footer
        assert_no_match /#{Regexp.escape(expected_footer_text)}$/, mail.body.to_s, "#{type} should NOT have footer from layout"
      else
        # Should have the footer
        assert_match    /#{Regexp.escape(expected_footer_text)}$/, mail.body.to_s, "#{type} should have footer from layout:\n#{mail.body.to_s}\n"
      end

      # Rails 3 is escaping some quote chars. Let's check for that.
      assert_no_match /&quot;/, mail.body.to_s, "#{type} seems to have some escaped quote chars"
      assert_no_match /&amp;/ , mail.body.to_s, "#{type} seems to have some escaped ampersand chars"
      assert_no_match %r{&#x[0-9a-f]+;}, mail.body.to_s, "#{type} seems to have some escaped entities"

      # Some trickiness:
      #  If there is a method defined, eg extra_docs_approve_tests then
      #  call it. Put additional specific tests for each type of email
      #  in these methods...
      extra_tests_method = "extra_#{type}_tests"
      if self.respond_to? extra_tests_method
        self.send(extra_tests_method,type,mail,*args)
      end

      #------------------------------------------------------------------
      # (This doesn't really belong here, neither does the debug_email_text
      # method, but they are handy so keep them for now)
      #
      # Uncomment this to see a big list of emails for debugging purposes. Eg:
      #  $ ruby -Ilib:test test/unit/notifier_test.rb > emails.txt
      # (Runs quicker if you comment out fixtures :all in test_helper)
      #puts debug_email_text(type,mail,:full)
    end
  end

  def self.baseline_test(method)
    test method do
      with_stubbed_const({:VERSION => '3.11.0-0'}, SystemVersion) do
        with_baselines(method, /errata-(\d+)\.txt$/) do |filename,id|
          # Ensure no mails left over from previous baseline
          ActionMailer::Base.deliveries = []
          Notifier.send(method, Errata.find(id)).deliver
          formatted_mail ActionMailer::Base.deliveries.last
        end
      end
    end
  end

  baseline_test 'partners_changed_files'
  baseline_test 'partners_new_errata'
  baseline_test 'request_rhnlive_push'
  baseline_test 'multi_product_to_qe'
  baseline_test 'multi_product_activated'
  baseline_test 'request_docs_approval'

  #--------------------------------------------------------------
  # I don't think it makes sense to spend loads of time writing
  # tests for the contents of emails. I think we can trust ActionMailer
  # to do its thing!
  #
  # But if we did want do that then this is the place.
  # The extra_*_tests methods gets called from above.
  #
  # Conceivably we might want to create a few emails of the same type
  # with different args, in which case don't use these methods. Instead
  # just write another test that sends an email with whatever args you
  # need for the particular test.

  # Here's one as an example:
  def extra_blocking_issue_tests(type,mail,*args)
    #debug_email_text(type,mail,:full)

    expected_recipients = @test_blocking_issue.errata.notify_and_cc_emails
    expected_recipients << @test_blocking_issue.blocking_role.blocking_issue_target
    expected_recipients.uniq!
    assert_equal expected_recipients.sort, mail.to.sort, "wrong recipients"

    assert_match @test_blocking_issue.summary, mail.body.to_s, "should show blocking issue summary"
    assert_match @test_blocking_issue.description, mail.body.to_s, "should show blocking issue description"

    # (Actually these are in the layout)
    assert_match @test_blocking_issue.errata.name_release_and_synopsis, mail.body.to_s, "should show name_release_and_synopsis"
    assert_match @test_blocking_issue.errata.status.to_s, mail.body.to_s, "should show status"

    # etc
  end
  #
  #--------------------------------------------------------------

  #
  # A utility method for displaying an email.
  #
  def debug_email_text(label,email,display_mode=:full)
    divider_text = "\n===[ #{label} ]#{'='*(70-label.length)}"

    case display_mode
    when :subject_only
      # Just the subject
      "%-32s | %s" % [label, email.subject]

    when :short
      # Just from/to/subject/body but not the headers
      "#{divider_text}\n" +
      "From:    #{email.from}\n" +
      "To:      #{(email.to||[]).join(', ')}\n" +
      "Subject: #{email.subject}\n\n" +
      "#{email.body.to_s}\n"

    else
      # The whole thing (will show all the headers)
      "#{divider_text}\n" +
      "#{email.to_s}"

    end
  end

  private

  def read_fixture(action)
    IO.readlines("#{FIXTURES_PATH}/notifier/#{action}")
  end

  def encode(subject)
    quoted_printable(subject, CHARSET)
  end
end
