(function(exports) {

    function ASHistory() {
        this.setUpHistory();
    };

    ASHistory.prototype.updateDiffButtons = function(on_button) {
	$('.as-history-tb-diff-button-group').children('a').css('background', 'initial');
        $('#' + on_button).css('background', '#ddd');
    };

    ASHistory.prototype.setDiffMode = function(mode) {
	if (mode == 'only') {
	    $('.history-diff-field').slideUp();
	    $('.history-clean-field').slideUp();
	    $('.history-change').slideDown();
	} else if (mode == 'clean') {
	    $('.history-diff-field').slideDown();
	    $('.history-clean-field').slideDown();
	    $('.history-change').slideUp();
	} else { // 'all'
	    $('.history-diff-field').slideUp();
	    $('.history-clean-field').slideDown();
	    $('.history-change').slideDown();
	    mode = 'all';
	}
        this.updateDiffButtons('as-history-tb-diff-' + mode + '-button');
	localStorage.setItem('as_history_show_diff_mode', mode);
    };

    ASHistory.prototype.showDiffOnlyClick = function() {
	this.setDiffMode('only');
    };

    ASHistory.prototype.showDiffAllClick = function() {
	this.setDiffMode('all');
    };

    ASHistory.prototype.showDiffCleanClick = function() {
	this.setDiffMode('clean');
    };

    ASHistory.prototype.setUpHistory = function() {
	this.setDiffMode(localStorage.getItem('as_history_show_diff_mode'));
	if (ASHISTORY_USER) {
	    $('#as-history-tb-user-button').css('background', '#ddd');
	}
        if (!isNaN(ASHISTORY_DIFF)) {
	    $('.history-version-box').each(function() {
		    var version = parseInt($(this).data('version'));
		    if (version < ASHISTORY_VERSION) {
			if (version == ASHISTORY_DIFF) {
			    $(this).children().addClass('history-showing-diff-version');
			} else if (version > ASHISTORY_DIFF) {
			    $(this).children().addClass('history-showing-diff-included-version');
			}
		    }
	    });
	}
    };

    exports.ASHistory = ASHistory;

}(window));
