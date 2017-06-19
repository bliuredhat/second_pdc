require 'test_helper'

class FileMetaApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as devel_user
  end

  test 'view file meta' do
    with_baselines('api/v1/filemeta', %r{errata-(\d+)\.json$}) do |filename,id|
      get "/api/v1/erratum/#{id}/filemeta"
      formatted_json_response
    end
  end

  test 'set file meta typical' do
    # single request to fully initialize all the metadata
    e = Errata.find(16396)
    meta = [
      [698253, 'RHEL Server Docker image'],
      [698251, 'Anaconda script for image'],
      [698252, 'Alternative anaconda script'],
    ]
    put_json(
      "/api/v1/erratum/#{e.id}/filemeta?put_rank=true",
      meta.map{|(id,title)| {:file => id, :title => title}}
    )
    assert_testdata_equal('api/v1/filemeta/put_full.json', formatted_json_response)

    assert_equal(
      meta.map{|(id,title)| {:brew_file_id => id, :title => title}},
      e.reload.brew_file_meta.order('RANK asc').
        map{|m| m.attributes.slice('brew_file_id', 'title').symbolize_keys}
    )
  end

  test 'put validates title' do
    put_json(
      "/api/v1/erratum/16396/filemeta",
      [{:file => 698253, :title => 'x'}]
    )
    assert_testdata_equal('api/v1/filemeta/put_bad_title.json', formatted_json_response)
  end

  test 'cannot modify meta when filelist is locked' do
    put_json(
      "/api/v1/erratum/16409/filemeta?put_rank=true",
      [
        {:file => 698263, :title => 'some file'},
        {:file => 698262, :title => 'other file'},
      ]
    )
    assert_testdata_equal 'api/v1/filemeta/put_locked.json', formatted_json_response
  end

  test 'put_rank must be boolean' do
    put_json(
      "/api/v1/erratum/16409/filemeta?put_rank=bad",
      [
        {:file => 698263, :title => 'some file'},
        {:file => 698262, :title => 'other file'},
      ]
    )
    assert_testdata_equal 'api/v1/filemeta/put_bad_put_rank.json', formatted_json_response
  end

  test 'put complains about duplicate file' do
    put_json(
      "/api/v1/erratum/16409/filemeta",
      [
        {:file => 698263, :title => 'some file'},
        {:file => 698263, :title => 'some file again'},
      ]
    )
    assert_testdata_equal 'api/v1/filemeta/put_dupe_file.json', formatted_json_response
  end

  test 'put complains about wrong file' do
    put_json(
      "/api/v1/erratum/16409/filemeta",
      [
        {:file => 3416484, :title => 'wrong file'},
      ]
    )
    assert_testdata_equal 'api/v1/filemeta/put_wrong_file_rank.json', formatted_json_response
  end

  test 'put complains about wrong keys in input' do
    put_json(
      "/api/v1/erratum/16409/filemeta",
      [
        {:foo => :bar}
      ]
    )
    assert_testdata_equal 'api/v1/filemeta/put_wrong_keys.json', formatted_json_response
  end

  test 'can set rank without changing title' do
    # advisory contains a mix of meta with title set/unset, so that we
    # can test that changing rank does not modify an existing title or
    # set a title (or fail) when the title is unset.
    e = Errata.find(16397)
    put_json(
      "/api/v1/erratum/#{e.id}/filemeta?put_rank=true",
      [
        {:file => 701212},
        {:file => 701217},
        {:file => 701215},
      ]
    )
    assert_testdata_equal 'api/v1/filemeta/put_rank_only.json', formatted_json_response

    assert_equal([
        {:brew_file_id => 701212, :title => 'Infinispan jar'},
        {:brew_file_id => 701217, :title => nil},
        {:brew_file_id => 701215, :title => 'Infinispan maven metadata'},
      ],
      e.reload.brew_file_meta.order('rank ASC').
        map{|m| m.attributes.slice('brew_file_id', 'title').symbolize_keys}
    )
  end

  test 'can partially set rank' do
    e = Errata.find(16397)
    put_json(
      "/api/v1/erratum/#{e.id}/filemeta?put_rank=true",
      [{:file => 701215}]
    )
    assert_testdata_equal 'api/v1/filemeta/put_rank_partial.json', formatted_json_response

    assert_equal([
        # The mentioned file was ranked first, as expected...
        {:rank => 1, :brew_file_id => 701215, :title => 'Infinispan maven metadata'},
        # The others were ranked arbitrarily (but stable)
        {:rank => 2, :brew_file_id => 701212, :title => 'Infinispan jar'},
        {:rank => 3, :brew_file_id => 701217, :title => nil},
      ],
      e.reload.brew_file_meta.order('rank ASC').
        map{|m| m.attributes.slice('rank', 'brew_file_id', 'title').symbolize_keys}
    )
  end

  test 'can set title without changing rank' do
    e = Errata.find(16397)

    # put_rank=false should be the default
    ['', '?put_rank=false'].each do |query|
      put_json(
        "/api/v1/erratum/#{e.id}/filemeta#{query}",
        [
          {:file => 701212, :title => 'first file'},
          {:file => 701217, :title => 'third file'},
          {:file => 701215, :title => 'second file'},
        ])
      assert_testdata_equal 'api/v1/filemeta/put_title_only.json', formatted_json_response
    end

    assert_equal([
        {:brew_file_id => 701212, :title => 'first file',  :rank => nil},
        {:brew_file_id => 701215, :title => 'second file', :rank => nil},
        {:brew_file_id => 701217, :title => 'third file',  :rank => nil},
      ],
      e.reload.brew_file_meta.order('id ASC').
        map{|m| m.attributes.slice('brew_file_id', 'title', 'rank').symbolize_keys}
    )
  end
end
