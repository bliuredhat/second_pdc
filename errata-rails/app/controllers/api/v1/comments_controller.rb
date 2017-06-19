module Api
  module V1
    # :api-category: Comments
    class CommentsController < ApiController

      #
      # Retrieve all advisory comments
      #
      # :api-url: /api/v1/comments?filter[key]=value
      # :api-method: GET
      # :api-request-example: {:filter => {:errata_id => 11112, :type => "AutomatedComment"}}
      # :api-response-example: file:test/data/api/v1/comments/index_filter_for_comment_type_advisory_11112.json
      #
      # Returns an array of comments ordered in descending order (newest first).
      # The array may be empty depending on the filters used. The meaning of
      # each attribute is documented under [GET /api/v1/comments/{id}]
      #
      # This is a [paginated API].
      #
      # ##### Filtering
      # The list of comments can be filtered by applying `filter[key]=value` as a
      # query parameter. All attributes of a comment - except `advisory_state` -
      # can be used as a filter.
      #
      def _api_doc_index
      end

      #
      # Get the details of a comment by its id.
      #
      # :api-url: /api/v1/comments/{id}
      # :api-method: GET
      # :api-response-example: file:test/data/api/v1/comments/show_745780.json
      #
      # Parameters are returned under a top-level key reflecting the comment type.
      #
      # ##### Attributes
      #
      # * `advisory_state`: The state the advisory was in when the comment was
      #                     created.
      # * `created_at`: time stamp the comment was created
      # * `errata_id`: advisory this comment belongs to
      # * `text`: comment text
      # * `who`: author of the comment
      # * `id`: unique identifier of the comment
      # * `type`: The type of the comment which can be any of:
      #           AdvisoryIdChangeComment, AutomatedComment, BatchChangeComment,
      #           BugAddedComment, BugRemovedComment, BuildSignedComment,
      #           CveChangeComment, DocsApprovalComment, JiraIssueAddedComment,
      #           JiraIssueRemovedComment, RpmdiffComment, SecurityApprovalComment,
      #           SignaturesRequestedComment, SignaturesRevokedComment,
      #           StateChangeComment, TpsComment, TpsCompleteComment
      #
      def _api_doc_show
      end

      def render_params
        { :order_by => 'comments.created_at DESC' }
      end
    end
  end
end
