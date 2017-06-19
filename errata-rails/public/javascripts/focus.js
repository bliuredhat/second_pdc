(function($) {
/* Functions relating to focus manipulation */

/* Set up a focus chain between forms.  For each form in the chain,
   submitting will switch focus to the next visible form.

   elems: a jQuery element selection.  May refer to forms or elements
   within forms.

   focus_fn: a function called on a form element to focus it.
   Defaults to jQuery.focus().
*/
function et_setup_form_focus_chain(elems, focus_fn) {
    var forms = elems.closest('form');
    focus_fn = focus_fn || function(elem) {
        elem.focus();
    };

    forms.each(function(idx,elem) {
        var next_forms = forms.slice(idx+1);
        $(elem).one('submit', function(){
            focus_fn(next_forms.filter(':visible').first());
        });
    });
}

/* Like et_setup_form_focus_chain, but instead of focusing the forms,
   it'll select the first visible input within a form.

   If opts.focus_now is true, also selects the first visible input
   within elems before returning.
*/
window.et_setup_input_focus_chain = function(elems, opts) {
    opts = opts || {};

    et_setup_form_focus_chain(
        elems,
        function(form) {
            // focus the visible input and select all the text, same as if it had been
            // focused by normal tabbing between fields.
            $('input:visible', form).first().select();
        }
    );

    if (opts.focus_now) {
        elems.filter(':visible').first().select();
    }
};

}(jQuery));
