# :api-category: Advisories
class Api::V1::ErratumFileMetaController < ApplicationController
  respond_to :json

  around_filter :with_validation_error_rendering
  around_filter :with_transaction, :except => [:index]

  before_filter :find_errata
  before_filter :find_meta

  #
  # Get the metadata for all applicable files in this advisory.
  #
  # :api-url: /api/v1/erratum/{id}/filemeta
  # :api-method: GET
  # :api-response-example: file:test/data/api/v1/filemeta/errata-16409.json
  #
  # Returned attributes include:
  #
  # * `file`: basic Brew file info.
  # * `rank`: defines the order used to display files on Customer Portal.
  # * `title`: a brief label associated with the file on Customer Portal.
  #
  # `rank` and `title` may be null, which means that the values have
  # not been set.
  #
  # Currently, only non-RPM files use metadata, but the callers of
  # this API shouldn't assume that this will always be the case.
  #
  def index
  end

  #
  # Update the metadata for some or all files in this advisory.
  #
  # :api-url: /api/v1/erratum/{id}/filemeta
  # :api-url: /api/v1/erratum/{id}/filemeta?put_rank=true
  # :api-method: PUT
  #
  # The request body must be an array of objects, each of which must
  # specify a file by its ID, and may specify attributes of the file's
  # metadata to set (currently "title" only).
  #
  # To adjust the rank of files, ensure the files are listed in the
  # request in the desired order, and set the *put_rank* query
  # parameter to *true*.  In this case, any files not included in the
  # request will be ranked arbitrarily (but in a stable order).
  #
  # Example: Set the title and rank of various files:
  #
  # * PUT to: `/api/v1/erratum/12345/filemeta?put_rank=true`
  # * With request body:\
  #    `[{"file":701212,"title":"Infinispan jar"},{"file":701215,"title":"Infinispan maven metadata"}]`
  #
  # Example: Set the title of one file, leave other metadata unmodified:
  #
  # * PUT to: `/api/v1/erratum/12345/filemeta`
  # * With request body:\
  #    `[{"file":701212,"title":"Infinispan jar"}]`
  #
  # Example: Adjust the ranking of files, leave other metadata unmodified:
  #
  # * PUT to: `/api/v1/erratum/12345/filemeta?put_rank=true`
  # * With request body:\
  #    `[{"file":701215},{"file":701212}]`
  #
  # Responds with the updated metadata, using the same format as [GET
  # /api/v1/erratum/{id}/filemeta].
  def update_multi
    put_rank = get_put_rank

    input = params['_json'] || []
    files = get_files(input)

    input.each do |x|
      meta = @meta.find{|m| m.brew_file_id == x['file']}
      if meta.nil?
        raise DetailedArgumentError.new(:file => "#{x['file']} is not a non-RPM file associated with this advisory")
      end

      if x.include?('title')
        meta.title = x['title']
        meta.save!
      end
    end

    if put_rank
      @meta = BrewFileMeta.set_rank_for_advisory(@errata, files)
      @meta.each(&:save!)
    end

    render 'index'
  end

  private

  def get_put_rank
    return false unless params.include?('put_rank')
    p = params['put_rank'].to_s.downcase
    return true  if p == 'true'
    return false if p == 'false'
    raise DetailedArgumentError.new(:put_rank => "expected true/false, got #{p}")
  end

  def get_files(input)
    files = input.map{|x| x['file']}
    if files.uniq != files
      raise DetailedArgumentError.new(:file => 'duplicate files were provided')
    end
    if files.compact != files
      raise DetailedArgumentError.new(:file => 'missing id')
    end
    files
  end

  def find_meta
    @meta = BrewFileMeta.
      find_or_init_for_advisory(@errata).
      sort_by{|m| [m.rank || 999999, m.brew_file_id]}
  end
end
