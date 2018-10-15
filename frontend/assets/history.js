(function(exports) {

    function ASHistory() {
        this.setUpHistory();
    };

    ASHistory.prototype.updateDiffButtons = function(on_button) {
	$('.as-history-tb-diff-button-group').children('a').css('background', 'initial');
        $('#' + on_button).css('background', '#eee');
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
    };

    exports.ASHistory = ASHistory;

}(window));
