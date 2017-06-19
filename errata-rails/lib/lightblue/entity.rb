module Lightblue
  module Entity

    class ContainerImage
      SCHEMA_VERSION  = '0.0.6'.freeze
      OBJECT_TYPE     = 'containerImage'.freeze

      module Field
        PARSED_DATA        = :parsed_data
        RPM_MANIFEST       = :rpm_manifest
        BREW_BUILD         = 'brew.build'.freeze
        REPOSITORIES       = 'repositories'.freeze
        LAST_UPDATE_DATE   = 'lastUpdateDate'.freeze
        CONTENT_ADVISORIES = 'content_advisories'.freeze
        ID                 = 'id'.freeze
        NAME               = 'name'.freeze
        REPOSITORY         = 'repository'.freeze
        TAGS               = 'tags'.freeze
        COMPARISON         = 'comparison'.freeze
        PUBLISHED          = 'published'.freeze
      end

      def initialize(client)
        @client = client
      end

      def repositories_for_brew_builds(ids)
        query = ContainerImage.repositories_for_brew_builds(ids).to_json
        client.post "find/#{OBJECT_TYPE}", query
      end

      def nvra_for_brew_build(id)
        query = ContainerImage.nvra_for_brew_build(id).to_json
        data = client.post "find/#{OBJECT_TYPE}", query
        return [] if data.blank?
        data.first[Field::PARSED_DATA][Field::RPM_MANIFEST]
      end

      def self.field_projection(field, args = {})
        { field: field, include: true }.merge(args)
      end

      def self.array_projection(field, args = {})
        { field: field, range: [0, 9999] }.merge(args)
      end

      def self.repositories_for_brew_builds(build_ids)
        {
          objectType: OBJECT_TYPE,
          version:    SCHEMA_VERSION,
          query: {
            field:  Field::BREW_BUILD,
            op:     '$in',
            values: build_ids
          },

          projection: [
            array_projection(Field::REPOSITORIES, projection: [
              array_projection(Field::CONTENT_ADVISORIES, projection: field_projection(Field::ID)),
              array_projection(Field::TAGS, projection: field_projection(Field::NAME)),
              field_projection(Field::REPOSITORY),
              field_projection(Field::COMPARISON, recursive: true),
              field_projection(Field::PUBLISHED)
            ]),
            field_projection(Field::BREW_BUILD),
            field_projection(Field::LAST_UPDATE_DATE)
          ]
        }
      end

      def self.nvra_for_brew_build(build_id)
        {
          objectType: OBJECT_TYPE,
          version:    SCHEMA_VERSION,
          query: {
            field:  Field::BREW_BUILD,
            op:     '=',
            rvalue: build_id
          },

          projection: {
            field:     "#{Field::PARSED_DATA}.#{Field::RPM_MANIFEST}",
            include:   true,
            recursive: true
          }
        }
      end

      private

      attr_reader :client
    end

  end #  Entity
end
