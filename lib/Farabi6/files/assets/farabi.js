var Farabi = {
/**
 * Starts Farabi... :)
 */
start: function() {

	// Cache dialog jQuery references for later use
	var $aboutDialog       = $('#about_dialog');
	var $helpDialog        = $("#help_dialog");
	var $openFileDialog    = $("#open_file_dialog");
	var $optionsDialog     = $("#options_dialog");
	var $podDialog         = $("#pod_dialog");
	var $runDialog         = $("#run-dialog");
	var $syntaxCheckButton = $(".syntax_check_button");
	var $showPodButton     = $(".show_pod_button");
	var $runButton         = $(".run-button");
		
	var currentEditor = null;
	var currentOutputEditor = null;
	var current = null;
	var editorCount = 0;

	$("#theme_selector").change(function() {
		var $selectedTheme = $(":selected", this);
		var theme = $selectedTheme.text();

		if(theme != 'default') {
			$("head").append("<link>");
			var css = $("head").children(":last");
			css.attr({
				rel:  "stylesheet",
				type: "text/css",
				href: "assets/3rd-party/codemirror-v4.6/theme/" + theme + ".css"
			});
		}

		currentEditor.setOption("theme", theme);
		currentOutputEditor.setOption("theme", theme);
	});

	function displayHelp(cm) {
		var selection = cm.getSelection();
		if(selection) {
			_displayHelp(selection, true);
		} else {
			// Search for token under the cursor
			var token = cm.getTokenAt(cm.getCursor());
			if(token.string) {
				_displayHelp($.trim(token.string), true);
			} else {
				_displayHelp('', true);
			}
		}
	}

	function _displayHelp(topic, bShowDialog) {
		$.get('/help_search', {"topic": topic}, function(results) {
			if(results.length > 0) {
				$(".topic").val(topic);
				var html = '';
				for(var i = 0; i < results.length; i++) {
					html += '<option value="' + i + '">' + results[i].podname + "  (" + results[i].context + ")" +'</option>';
				}

				$(".results")
					.html(html)
					.change(function() {
						var index = $(':selected', this).val();
						$(".preview").html(results[index].html);
					}).change().show();
			} else {
				$(".topic").val(topic);
				$(".results").html('').hide();
				$(".preview").html('<span class="text-error">No results found!</span>');
			}
			if(bShowDialog) {
				$('a[href="#learn-tab"]').tab('show');
				$(".topic").select().focus();
			}
		});
	}

	function changeMode(cm, modeFile, mode) {
		if(typeof mode == 'undefined') {
			mode = modeFile;
		}
		if(mode == 'perl6') {
			// Special case for Perl 6 (since it is outside CodeMirror for now)
			CodeMirror.modeURL = "assets/mode-perl6.js";
		} else {
			CodeMirror.modeURL = "assets/3rd-party/codemirror-v4.6/mode/%N.js";
		}
		cm.setOption("mode", mode);
		CodeMirror.autoLoadMode(cm, modeFile);
	}

	function plural(number) {
		if(number == 1) {
			return 'st';
		} else if(number == 2) {
			return 'nd';
		} else {
			return 'th';
		}
	}

	function showEditorStats(cm) {
		var cursor = cm.getCursor();
		var selection = cm.getSelection();
		var line_number = cursor.line + 1;
		var column_number = cursor.ch + 1;
		$('#editor_stats').html(
			'<strong>' + line_number + '</strong>' + plural(line_number) + ' line' +
			', <strong>' + column_number + '</strong>' + plural(column_number) + ' column' +
			', <strong>' + cm.lineCount() + '</strong>&nbsp;lines' +
			(selection ?  ', <strong>' + selection.length +'</strong>&nbsp;selected characters' : '')  +
			', <strong>' + cm.getValue().length + '</strong>&nbsp;characters' +
			', <strong>' + cm.lineCount() + '</strong>&nbsp;Lines&nbsp;&nbsp;'
		);
	}

	$("#mode_selector").change(function() {
		var $selectedMode = $(":selected", this);
		var mode = $selectedMode.val();
		if(mode == 'clike') {
			changeMode(editor, mode, 'text/x-csrc');
		} else if(mode == 'plsql') {
			changeMode(editor, mode, 'text/x-plsql');
		} else {
			changeMode(editor, mode);
		}
	});

	Mousetrap.bind('alt+enter', function() {
		$runButton.click();
	});

	Mousetrap.bind('f6', function() {
		$syntaxCheckButton.click();
	});

	Mousetrap.bind('f9', function() {
		$showPodButton.click();
	});

	Mousetrap.bind('alt+f11', function() {
		$(".fullscreen-button").click();
	});

	Mousetrap.bind('esc', function() {
		if (currentEditor.getOption("fullScreen")) {
			currentEditor.setOption("fullScreen", false);
		}
	});

	Mousetrap.bind('alt+n', function() {
		$(".new-file-button").click();
	});

	Mousetrap.bind('alt+o', function() {
		$(".open_file_button").click();
	});

	Mousetrap.bind('alt+s', function() {
		$(".save_file_button").click();
	});

	var editors = [];
	var addEditor = function(mode) {

		var editorId = "editor" + editorCount;
		var outputEditorId = "output" + editorCount;
		editorCount++;
		$("#editors").append(
			'<div class="column">' +
			'<div class="ui segment">' +
			'<div class="ui top left attached label">Editor #' + editorCount + '</div>' +
			'<div class="ui segment">' +
			'<div class="ui disabled inverted dimmer"><div class="ui loader"></div></div>'+
			'<a class="ui top right attached label run_code">Run</a>' +
			'<textarea id="' + 
			editorId + 
			'" placeholder="Code goes here..." cols="80" rows="10"></textarea>' +
			'</div>' +
			'<div class="ui segment">' +
			'<div class="ui disabled inverted dimmer"><div class="ui loader"></div></div>'+
			'<textarea id="' + outputEditorId + '" placeholder="Output will be shown here..."  cols="80" rows="10">' +
			'</textarea><p class="time_spent hide"></p></div></div></div><div class="ui divider"></div>');

		var editor = CodeMirror.fromTextArea(document.getElementById(editorId), {
			lineNumbers                : true,
			matchBrackets              : true,
			tabSize                    : 4,
			indentUnit                 : 4,
			indentWithTabs             : true,
			highlightSelectionMatches  : true,
			styleSelectedText          : true,
			styleActiveLine            : true,
			viewportMargin             : Infinity,
			extraKeys      : {
				"F1": function(cm) {
					//displayHelp(cm);
				},
				"Alt-Enter": function(cm) {
					Mousetrap.trigger('alt+enter');
				},
				"F6": function(cm) {
					Mousetrap.trigger('f6');
				},
				"F9": function(cm) {
					Mousetrap.trigger('f9');
				},
				"Alt-F11" : function(cm) {
					Mousetrap.trigger('alt+f11');
				},
				"Esc" : function(cm) {
					Mousetrap.trigger('esc');
				},
				"Alt-N": function(cm) {
					Mousetrap.trigger('alt+n');
				},
				"Alt-O": function(cm) {
					Mousetrap.trigger('alt+o');
				},
				"Alt-S": function(cm) {
					Mousetrap.trigger('alt+s');
				}
			}
		});

		var outputEditor = CodeMirror.fromTextArea(document.getElementById(outputEditorId), {
			tabSize                   : 4,
			indentUnit                : 4,
			mode                      : 'text/plain',
			indentWithTabs            : true,
			highlightSelectionMatches : true,
			styleSelectedText         : true,
			readOnly                  : true,
			viewportMargin            : Infinity
		});

		currentEditor = editor;
		currentOutputEditor = outputEditor;

		editors.push({
			"editor"          : editor,
			"editorId"        : editorId,
			"outputEditor"    : outputEditor,
			"outputEditorId"  : outputEditorId
		});

		// Hook up with cursor activity event
		editor.on("cursorActivity", function(cm) {
			// Show editor statistics
			showEditorStats(cm);
		});

		// Handle editor switch
		editor.on("focus", function(cm) {
			for(var i in editors) {
				var e = editors[i];
				if(e.editor == cm) {
					current = e;
					currentEditor = e.editor;
					currentOutputEditor = e.outputEditor;
					break;
				}
			}
		});

		$(".run_code").click(function() {
			var id = $(this).next('textarea').attr('id');
			for(var i in editors) {
				var e = editors[i];
				if(e.editorId == id) {
					current = e;
					currentEditor = e.editor;
					currentOutputEditor = e.outputEditor;
					break;
				}
			}
			$runButton.click();
		});

		// Run these when we exit this one
		setTimeout(function() {
			// Editor is by default Perl
			changeMode(editor, mode);

			// Show editor stats at startup
			showEditorStats(editor);

			// Use the selected theme
			$("#theme_selector").change();

			// focus!
			editor.focus();
		}, 0);
	};

	addEditor('perl6');

	var searchFile = function() {
		var filename = $("#file", $openFileDialog).val();
		$("#search-results", $openFileDialog).empty();
		$("#ok-button", $openFileDialog).attr("disabled","disabled");
		$.ajax({
			type:    "POST",
			url:     "/search_file",
			data:    { "filename": filename },
			success: function(results) {
				var html = '';
				for(var i = 0; i < results.length; i++) {
					html += "<option id='" + results[i].file + "' "  + 
						((i == 0) ? "selected" : "") + 
						">" + 
						results[i].name + 
						"</option>";
				}
				$("#ok-button", $openFileDialog).removeAttr("disabled");
				$("#search-results", $openFileDialog).html(html);
			},
			error:   function(jqXHR, textStatus, errorThrown) {
				console.error("Error:\n" + textStatus + "\n" + errorThrown);
			}
		});
	};

	var searchFileTimeoutId;
	$("#file", $openFileDialog).on('input', function() {
		clearTimeout(searchFileTimeoutId);
		searchFileTimeoutId = setTimeout(searchFile, 500);
	});

	$("#file", $openFileDialog).keyup(function(evt) {
		var keyCode = evt.keyCode;
		if(keyCode == 40) {
			$("#search-results", $openFileDialog).focus();
		} else if(keyCode == 13) {
			var $okButton = $("#ok-button", $openFileDialog);
			if(!$okButton.attr('disabled')) {
				$okButton.click();
			}
		}
	});

	$("#ok-button", $openFileDialog).click(function() {
		var filename = $("#search-results option:selected", $openFileDialog).attr('id');
		if (!filename) {
			console.warn("file name is empty");
			return;
		}

		$.ajax({
			type:    "POST",
			url:     "/open_file",
			data:    { "filename": filename },
			success: function(code) {
				addEditor('perl6');
				currentEditor.setValue(code);
			},
			error:   function(jqXHR, textStatus, errorThrown) {
				console.error("Error!" + textStatus + ", " + errorThrown);
			}
		});
	});

	$(".open_file_button").click(function() {
		$openFileDialog.modal('show');
		$("#file", $openFileDialog).val('').focus();
		$("#search-results", $openFileDialog).empty();
		$("#ok-button", $openFileDialog).attr("disabled","disabled");
	});

	$(".save_file_button").click(function() {
		console.warn("TODO implement Save file clicked");	
	});

	$(".save_as_file_button").click(function() {
		var filename = prompt("File name to save as?");
		if(!filename) {
			return;
		}
		$.post("/save_as_file",
             { "filename": filename },
             function() {
				alert("Save as worked?!");
             }
         );
	});

	$(".fullscreen-button").click(function() {
		currentEditor.setOption("fullScreen", !currentEditor.getOption("fullScreen"));
		$("#left_menu_sidebar").sidebar('toggle');
	});

	$(".open_url_button").click(function() {
		var url = prompt("Please Enter a http/https file location:" + 
			"\ne.g https://raw.github.com/ihrd/uri/master/lib/URI.pm");
		if(!url) {
			return;
		}
		$.post('/open_url',
			{ "url": url },
			function(code) {
				currentEditor.setValue(code);
			}
		);
	});

	$runButton.click(function()
	{
		// Loading...
		var $outputSegment = $("#" + current.outputEditorId)
			.closest(".ui.segment"); 
		var $outputDimmer = $outputSegment
			.find(".dimmer");
		$outputDimmer.addClass("active").removeClass("disabled");
		$outputSegment.find(".time_spent").addClass("hide");

		$.post('/run/rakudo', {"source": currentEditor.getValue() }, function(result)
		{

			// Hide the "loading" dimmer
			$outputDimmer.addClass("disabled").removeClass("active");

			currentOutputEditor.setValue(result.output);
			var doc = currentOutputEditor.getDoc();

			for(var i in result.ranges)
			{
				var r = result.ranges[i];
				currentOutputEditor.markText(
					doc.posFromIndex(r.from),
					doc.posFromIndex(r.to),
					{ className: r.colors }
				);
			}

			// Display script runing time
			$outputSegment
				.find(".time_spent")
				.removeClass("hide")
				.html("Spent " + result.duration + " second(s)");
		});
	});

	var syntaxCheckWidgets = [];
	var syntaxCheck = function(cm) {

		$.post('/syntax_check', {"source": cm.getValue() }, function(result) {
			var problems = result.problems;
			var i, problem;
			for (i = 0; i < syntaxCheckWidgets.length; i++) {
				cm.removeLineWidget(syntaxCheckWidgets[i].widget);
			}
			syntaxCheckWidgets.length = 0;
			if(problems.length > 0) {
				for(i = 0; i < problems.length; i++) {
					problem = problems[i];

					// Add syntax check error under the editor line
					var msg = $('<div class="farabi-error">' +
						'<span class="farabi-error-icon">!!</span>' + 
						problem.description + '</div>')
						.appendTo(document)
						.get(0);
					syntaxCheckWidgets.push({
						'problem' : problem,
						'widget'  : cm.addLineWidget(problem.line_number - 1, msg, {coverGutter: true, noHScroll: true}),
						'node'    : msg
					});
				}
			}
			currentOutputEditor.setValue(result.output);
		});
	};

	$('.about_button').click(function() {
		$('#jquery-version').html($().jquery);
		$('#codemirror-version').html(CodeMirror.version);
		$aboutDialog.modal("show");
	});

	$('.help_button').click(function() {
		$helpDialog.modal("show");
	});

	$('.options_button').click(function() {
		$optionsDialog.modal("show");
	});

	// Hide and setup the on-hide-focus-the-editor event
	$(".modal").on('hidden', function() {
		currentEditor.focus();
	});

	$("#line_numbers_checkbox").change(function() {
		currentEditor.setOption('lineNumbers', $(this).is(':checked'));
	});

	$('.ui.dropdown').dropdown({
		on: 'hover'
	});


	$syntaxCheckButton.click(function() {
		syntaxCheck(currentEditor);
	});
	$showPodButton.click(function() {
		$.post('/pod_to_html', 
			{ "source": currentEditor.getValue() }, 
			function(html) {
				$('.content', $podDialog).html(html);
				$podDialog.modal('show');
			}
		);
	});

	$("#tab_size").change(function() {
		var tabSize = $(this).val();
		if($.isNumeric(tabSize)) {
			$(this).parent().parent().removeClass("error");
			currentEditor.setOption('tabSize', tabSize);
		} else {
			$(this).parent().parent().addClass("error");
		}
	});

	$(".new-file-button").click(function() {
		addEditor('perl6');
	});
	
	$("#toggle_left_menu_sidebar").on('click', function() {
		$("#left_menu_sidebar").sidebar('toggle');
	});

	setTimeout(function() {
		$("#toggle_left_menu_sidebar").click();
	}, 2500);
	
}
};

// Start Farabi when the document loads
$(function() {
	Farabi.start();
});
