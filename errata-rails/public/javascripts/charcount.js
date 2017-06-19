/*
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Title :       charcount.js
Author :      Terri Ann Swallow
URL :         http://www.ninedays.org/
Project :     Ninedays Blog
Copyright:    (c) 2008 Sam Stephenson
              This script is is freely distributable under the terms of an MIT-style license.

Description : Functions in relation to limiting and displaying the number of characters allowed in a textarea
Version:      2.1
Changes:      Added overage override.  Read blog for updates: http://blog.ninedays.org/2008/01/17/limit-characters-in-a-textarea-with-prototype/

Created :     1/17/2008 - January 17, 2008
Modified :    5/20/2008 - May 20, 2008

Functions:    init()            Function called when the window loads to initiate and apply character counting capabilities to select textareas
              charCounter(id, maxlimit)  Function that counts the number of characters, alters the display number and the calss applied to the display number
              makeItCount(id, maxsize) Function called in the init() function, sets the listeners on teh textarea nd instantiates the feedback display number if it does not exist
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
*/
// Event.observe(window, 'load', init);


//
// Want to throttle this for people with slow browsers.
// See Bug 852756.
//
// http://remysharp.com/2010/07/21/throttling-function-calls/
//
function function_throttle(fn, delay) {
  var timer = null;
  if (!delay) delay = 750; // default to 750 millisecs
  return function () {
    var context = this, args = arguments;
    clearTimeout(timer);
    timer = setTimeout(function(){
      fn.apply(context, args);
    }, delay);
  };
}

function charCounter(id, maxlimit){
  var id_sel = '#' + id;
  var counter_id = '#counter-'+id;
  var char_count = $(id_sel).val().length;
  if (!$('#counter-'+id)){
    $(id_sel).after('<div id="counter-'+id+'"></div>');
  }

  if(char_count >= maxlimit){
    $(counter_id).addClass('redNote');
    $(counter_id).removeClass('charcount-safe');
  } else {
    $(counter_id).removeClass('redNote');
    $(counter_id).addClass('charcount-safe');
  }
  $(counter_id).html( char_count + '/' + maxlimit );

}

function makeItCount(id, maxsize){
  var id_sel = '#' + id;
  if ($(id_sel)){
    $(id_sel).bind('keyup keypress', function(){charCounter(id, maxsize);});
    charCounter(id, maxsize);
  }
}
