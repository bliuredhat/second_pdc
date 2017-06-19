(function($) {
//
// When editing a docs reviewer from the docs queue, we populate the modal form
// with the relevant data then show the form. (Previously there was a separate modal
// form for every row in the table, which was causing it to be heavy and slow).
// See Bug 870163.
//
$(document).ready(function()
  {
    $('[data-reviewer-id]').click(function(e) {
        var edit_modal = $('#edit_reviewer_modal_container');
        var reviewer_user_id = $(this).data('reviewerId');
        var errata_id = $(this).data('errataId');

        var advisory_name = $('#link_to_' + errata_id).text();
        var synopsis = $('#synopsis_' + errata_id).text();

        edit_modal.find('.errata_fulladvisory').text(advisory_name);
        edit_modal.find('.errata_synopsis').text(synopsis);

        // Update the select
        edit_modal.find('#reviewer_select').
            val(reviewer_user_id). // set new value in the select
            trigger("liszt:updated"); // make chosen widget refresh

        // Clear the comment field
        edit_modal.find('textarea[name=comment]').val('');

        // Update the hidden errata id field
        edit_modal.find('input[name=id]').val(errata_id);

        // Now open the modal
        edit_modal.modal('show');

        // So we don't follow the link
        return false;
    });

    $('.eso-tab-content').on('click', '.btn-cancel-modal', function(event) {
        event.preventDefault();
        $(this).closest('.modal').modal('hide');
    });
  });

}(jQuery));
