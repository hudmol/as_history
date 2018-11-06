// in_a_rush key bindings
$(function() {

  if (typeof InARush !== 'undefined') {

    var translate = function(s) {
      return (HISTORY_IN_A_RUSH_TRANSLATIONS[s] || s);
    };

    InARush.Bindings.addBinding({
      id: 'system_history',
      keySequence: ['h'],
      handler: function () { window.location.href = APP_PATH + 'history'; },
      description: translate('system_history'),
      condition: function () { return !window.location.href.includes('/history'); },
      category: translate('category_history'),
    });

  }

});
