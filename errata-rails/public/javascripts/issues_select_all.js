(function($) {
//
// For doing 'select all' or 'select none' on lists of issues (Bugs/JIRA Issues).
// See app/helpers/issues_helper.rb
//
function set_all_issue_row_checkboxes(clicked, set_to) {
  $(clicked).closest('table').find('.issue_row_checkbox').prop('checked', set_to);
}

window.issues_select_all = function(clicked) { set_all_issue_row_checkboxes(clicked, 1); };
window.issues_select_none = function(clicked) { set_all_issue_row_checkboxes(clicked, 0); };

}(jQuery));