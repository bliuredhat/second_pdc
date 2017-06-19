
class MockedBrew
  include Mocha::API # to use the mock method

  attr_reader :mocked_brew

  def initialize
    @mocked_brew = mock
    @mocked_brew.expects(:getBuild).never
    @mocked_brew.expects(:listBuildRPMs).never
    # listTags remains permitted (see Bug 1167143).

    Brew.stubs(get_connection: Brew.get_connection)
    Brew.get_connection.instance_variable_set('@proxy', mocked_brew)
  end

  def mock_builds(builds, opts = {})
    mark_existing_builds(
      builds[:good],
      product_listings: opts[:listing_variants].map do |v|
        [v, opts[:valid_product_listing]]
      end
    )

    mark_existing_builds(
      builds[:nolisting],
      product_listings: opts[:listing_variants].map do |v|
        # These builds can successfully fetch product listings,
        # but they're empty
        [v, ->(_nvr) { {} }]
      end
    )

    mark_existing_builds(
      builds[:nonrpm],
      nonrpm: true,
      # These builds don't have SRPMs and therefore crash on getProductListings
      product_listings: opts[:listing_variants].map do |v|
        [v, ->(nvr) { XMLRPC::FaultException.new(1000, "Could not find any RPMs for build #{nvr}") }]
      end
    )

    mark_nonexisting_builds(builds[:notexist], times: opts[:product_version_count])
    mark_bad_builds(builds[:bad], times: opts[:product_version_count])

    # for listTags we use a simple mock which just returns a valid tag
    # for this advisory, for any build.
    mocked_brew.expects(:listTags).at_least_once.tap do |exp|
      # Would like to return a new copy indefinitely, but I can't see
      # a way to do it in the mocha API, so just do it a lot of times
      100.times do
        # some code does in-place modification of this array, so we need
        # to mock a copy each time.
        exp = exp.returns(opts[:tags].dup)
      end
    end
  end

  private


  def next_build_id
    @_build_id ||= BrewBuild.order('id DESC').limit(1).first.id + 100
    @_build_id += 1
  end

  def next_file_id
    @_file_id ||= BrewFile.order('id DESC').limit(1).first.id + 100
    @_file_id += 1
  end

  def mark_existing_builds(nvrs, opts = {})
    nvrs.each do |nvr|
      nvr =~ /^(.*?)-([^-]+)-([^-]+)$/
      build_id = next_build_id
      file_id = next_file_id
      mocked_brew
        .expects(:getBuild)
        .with(nvr).times(opts[:times] || 1)
        .returns(
          'nvr' => nvr, 'state' => 1,
          'version' => $2, 'release' => $3,
          'epoch' => 0, 'package_name' => $1,
          'id' => build_id
        )

      if opts[:nonrpm]
        mocked_brew
          .expects(:listArchives)
          .with(build_id, nil, nil, nil, 'image')
          .once
          .returns(
            [{
              'id' => file_id,
              'type_id' => BrewArchiveType.find_by_name!('tar').id,
              'arch' => 'x86_64',
              'filename' => 'some-file.tar'
            }]
          )
        mocked_brew.expects(:listBuildRPMs).with(build_id)
                   .once.returns([])
      else
        mocked_brew
          .expects(:listArchives)
          .with(build_id, nil, nil, nil, 'image').once
          .returns([])

        mocked_brew
          .expects(:listBuildRPMs).with(build_id).once
          .returns(
            [
              { 'id' => file_id, 'arch' => 'x86_64', 'nvr' => nvr },
              { 'id' => next_file_id, 'arch' => 'src', 'nvr' => nvr }
            ]
          )
      end
      mocked_brew.expects(:listArchives).with(build_id, nil, nil, nil, 'win').once.returns([])
      mocked_brew.expects(:listArchives).with(build_id, nil, nil, nil, 'maven').once.returns([])

      (opts[:product_listings] || []).each do |(variant, generator)|
        expect = mocked_brew.expects(:getProductListings).with(variant, build_id)

        value = generator.call(nvr)
        if value.is_a?(Exception)
          expect.raises(value)
          # when raising an exception on split product listings, our
          # client bails out on the first problem.  However, the order
          # in which product listings are queried is undefined, so we
          # can't tell which call to expect.  So weaken the test in
          # this case.
          expect.at_least(0)
        else
          expect.at_least_once.returns(value)
        end
      end
    end
  end

  def mark_nonexisting_builds(nvrs, times: 1)
    nvrs.each do |nvr|
      mocked_brew.expects(:getBuild).with(nvr)
                 .times(times).returns(nil)
    end
  end

  def mark_bad_builds(nvrs, times: 1)
    nvrs.each do |nvr|
      mocked_brew
        .expects(:getBuild).with(nvr)
        .times(times)
        .raises(XMLRPC::FaultException.new(1000, "invalid format: #{nvr}"))
    end
  end

end
