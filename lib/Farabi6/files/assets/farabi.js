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
				href: "assets/3rd-party/codemirror-v4.8/theme/" + theme + ".css"
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
			CodeMirror.modeURL = "assets/perl6-mode.js";
		} else {
			CodeMirror.modeURL = "assets/3rd-party/codemirror-v4.8/mode/%N.js";
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
		$(".debug_step_in_button").click();
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
		$(".sidebar").sidebar('hide');
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

	Mousetrap.bind('alt+m', function() {
		$(".module_search_button").click();
	});

	Mousetrap.bind('alt+r', function() {
		$(".repl_button").click();
	});

	Mousetrap.bind('alt+h', function() {
		$(".help_search_button").click();
	});

	var editors = [];
	var addEditor = function(mode) {

		if(!mode) {
			throw "Parameter 'mode' is required";
		}

		var editorId = "editor" + editorCount;
		var outputEditorId = "output" + editorCount;
		editorCount++;
		$("#editors").append(
			'<div class="column">' +
				'<div class="ui segment">' +
					'<div class="ui top attached label">Editor #' + editorCount + '</div>' +
					'<p>' +
						'<div class="ui two column grid">' +
							'<div class="column">' +
								'<div class="ui segment">' +
									'<div class="ui disabled inverted dimmer"><div class="ui loader"></div></div>'+
									'<a class="ui top right attached label run_code">Run</a>' +
									'<textarea id="' + 
									editorId + 
									'" placeholder="Code goes here..." cols="80" rows="10"></textarea>' +
								'</div>' +
							'</div>' +
							'<div class="column">' +
								'<div class="ui segment">' +
									'<div class="ui disabled inverted dimmer"><div class="ui loader"></div></div>'+
									'<textarea id="' + outputEditorId + '" placeholder="Output will be shown here..."  cols="80" rows="10">' +
									'</textarea>' +
									'<p class="time_spent hide"></p>' +
									'<p class="profile_results hide"><a href="#" target="_blank">Profile results</a></p>' +
								'</div>' +
							'</div>' +
						'</div>' +
					'</p>'+
				'</div>' +
			'</div>' +
			'<div class="ui divider"></div>'
		);

		var lint = function(text, updateLinting, options, cm) {

			$.post('/syntax_check', {"source": text }, function(result) {
				var problems = result.problems;
				var messages = [];
				for(var i = 0; i < problems.length; i++) {
					var problem = problems[i];
					var line    = problem.line_number - 1;
					messages.push({
						from     : { line: line, ch: 0 },
						to       : { line: line, ch: 0 },
						message  : problem.description,
						severity : "error"
					});
				}
				updateLinting(cm, messages);
			});
		};

		var editor = CodeMirror.fromTextArea(document.getElementById(editorId), {
			lineNumbers                : true,
			matchBrackets              : true,
			tabSize                    : 4,
			indentUnit                 : 4,
			indentWithTabs             : true,
			highlightSelectionMatches  : true,
			styleSelectedText          : true,
			styleActiveLine            : true,
			showTrailingSpace          : true,
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
				},
				"Alt-M": function(cm) {
					Mousetrap.trigger('alt+m');
				},
				"Alt-R": function(cm) {
					Mousetrap.trigger('alt+r');
				},
				"Alt-H": function(cm) {
					Mousetrap.trigger('alt+h');
				}
			},
			gutters: ["CodeMirror-lint-markers"],
			lint: {
				getAnnotations: lint,
				async : true
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
						((i === 0) ? "selected" : "") +
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
		$(".sidebar").sidebar('hide');
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

	var colorANSI = function(cm, ranges)
	{
		var doc = cm.getDoc();
		for(var i in ranges)
		{
			var r = ranges[i];
			cm.markText(
				doc.posFromIndex(r.from),
				doc.posFromIndex(r.to),
				{ className: r.colors }
			);
		}
	};
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
			colorANSI(currentOutputEditor, result.ranges);

			// Display script runing time
			$outputSegment
				.find(".time_spent")
				.removeClass("hide")
				.html("Spent " + result.duration + " second(s)");
		});
	});

	var syntaxCheck = function(cm) {

		$.post('/syntax_check', {"source": cm.getValue() }, function(result) {
			currentOutputEditor.setValue(result.output);
			colorANSI(currentOutputEditor, result.ranges);
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

	$("#actions_sidebar").sidebar( {
		onChange: function() {
			if($(this).hasClass("active")) {
				$("#toggle_actions_sidebar").css("left", $(this).width() + "px");
			} else {
				$("#toggle_actions_sidebar").css("left", "0px");
			}
		}
	});

	$("#toggle_actions_sidebar").on('click', function() {
		$("#actions_sidebar").sidebar('toggle');
	});

	$(".repl_button").on('click', function() {
		$("#repl_sidebar").sidebar('toggle');
		$("#repl_expr").focus();
	});

	setTimeout(function() {
		$("#toggle_actions_sidebar").click();
	}, 500);

	$("#repl_expr").keypress(function(evt)
	{
		if(evt.keyCode == 13)
		{
			var $dimmer = $("#repl_expr").closest(".ui.segment").find(".dimmer");
			$dimmer.addClass("active").removeClass("disabled");
			$.post('/eval_repl_expr',
				{ "expr": $(this).val() },
				function(result) {
					var history = $("#repl_history").val();
					if(history !== "") {
						$("#repl_history").val(history + "\n" + result.output);
					} else {
						$("#repl_history").val(result.output);
					}
				}
			).fail(
				function() {
					var history = $("#repl_history").val();
					if(history !== "") {
						$("#repl_history").val(history + "\n" + "an error occured");
					} else {
						$("#repl_history").val(result.output);
					}
				}
			).always(
				function() {
					$("#repl_expr").val('');
					$dimmer.addClass("disabled").removeClass("active");
				});
			return false;
		}
		return true;
	});

	$(".profile_button").click(function()
	{
		// Loading...
		var $outputSegment = $("#" + current.outputEditorId)
			.closest(".ui.segment");
		var $outputDimmer = $outputSegment
			.find(".dimmer");
		$outputDimmer.addClass("active").removeClass("disabled");
		$outputSegment.find(".time_spent").addClass("hide");

		$.post('/profile/rakudo', {"source": currentEditor.getValue() }, function(result)
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

			// Provide a link to download the profile HTML file in a new tab
			$outputSegment
				.find(".profile_results")
				.removeClass("hide")
				.find("a")
				.attr("href", "/profile/results?id=" + result.profile_id);

		});
	});

	$(".module_search_button").click(function()
	{
		$("#module_search_sidebar").sidebar('toggle');
		$("#module_search_pattern").focus().keypress();
	});

	var moduleSearchTimeoutId;
	var lastModuleSearchPattern;
	$("#module_search_pattern").keyup(function()
		{
			var pattern = $(this).val();

			// Prevent redundants searches caused by other non-printing keys
			if(pattern == lastModuleSearchPattern) {
				return;
			}
			lastModuleSearchPattern = pattern;

			clearTimeout(moduleSearchTimeoutId);
			moduleSearchTimeoutId = setTimeout(
				function()
				{
					var $dimmer = $("#module_search_results").closest(".ui.segment").find(".dimmer");
					$dimmer.addClass("active").removeClass("disabled");
					$.post('/module/search',
						{
							"pattern": pattern
						},
						function(result)
						{
							$("#module_search_results").val(result.results);
							var html = '';
							var results = result.results;
							for(var i in results)
							{
								var r = results[i];
								html += '<div class="item">' +
									'<i class="folder outline icon"></i>' +
									'<div class="content">' +
									'<a class="header" href="' + r.url + '" target="_blank">' + r.name+ '</a>' +
									'<div class="description">' + r.desc +'</div>' +
									'</div>' +
									'</div>';
							}

							if(html === '') {
								html = "No results found";
							}

							$("#module_search_results").html(html);

							$dimmer.addClass("disabled").removeClass("active");
						}
					);
				},
				300
			);
		}
	);

	var runGitCommand = function(command, result)
	{
		if(!command)
		{
			throw "Parameter 'command' is required";
		}

		if(!result)
		{
			throw "Parameter 'result' is required";
		}

		var $outputSegment = $("#" + current.outputEditorId)
			.closest(".ui.segment");

		// Show "loading" dimmer
		var $outputDimmer = $outputSegment
			.find(".dimmer");
		$outputDimmer.addClass("active").removeClass("disabled");

		// Hide time spent
		$outputSegment.find(".time_spent").addClass("hide");

		$.post(
			'/git/' + command,
			{},
			function(result)
			{
				// Hide the "loading" dimmer
				$outputDimmer.addClass("disabled").removeClass("active");

				currentOutputEditor.setValue(result.output);
				colorANSI(currentOutputEditor, result.ranges);

				// Display script runing time
				$outputSegment
					.find(".time_spent")
					.removeClass("hide")
					.html("Spent " + result.duration + " second(s)");
				}
		);
	};

	$(".git_diff_button").click(
		function(result)
		{
			runGitCommand('diff', result);
		}
	);

	$(".git_log_button").click(
		function(result)
		{
			runGitCommand('log', result);
		}
	);

	$(".git_status_button").click(
		function(result)
		{
			runGitCommand('status', result);
		}
	);

	$(".help_search_button").click(function()
	{
		if(! $("#help_search_sidebar").hasClass("active"))
		{
			var cm = currentEditor;
			var selection = cm.getSelection();
			var topic;
			if(selection)
			{
				topic = selection;
			} else
			{
				// Get cursor
				var cursor = cm.getCursor();

				//WORKAROUND: Resolve getTokenAt bug by adding 1 to column
				var c = {
					line: cursor.line,
					ch: cursor.ch + 1
				};

				// Search for token under the cursor
				var token = cm.getTokenAt(c);
				if(token.string)
				{
					topic = $.trim(token.string);
				} else
				{
					topic = '';
				}
			}

			$("#help_search_pattern").val(topic);
		}

		setTimeout(function() {
			$("#help_search_sidebar").sidebar('toggle');
			$("#help_search_pattern").focus().keypress();
		}, 0);
	});

	var helpSearchTimeoutId;
	var lastHelpSearchPattern;
	$("#help_search_pattern").keyup(function()
		{
			var pattern = $(this).val();

			// Prevent redundants searches caused by other non-printing keys
			if(pattern == lastHelpSearchPattern) {
				return;
			}
			lastHelpSearchPattern = pattern;

			clearTimeout(helpSearchTimeoutId);
			helpSearchTimeoutId = setTimeout(
				function()
				{
					var $dimmer = $("#help_search_results").closest(".ui.segment").find(".dimmer");
					$dimmer.addClass("active").removeClass("disabled");
					$.post('/help/search',
						{
							"pattern": pattern
						},
						function(result)
						{
							$("#help_search_results").val(result.results);
							var html = '';
							var results = result.results;
							for(var i in results)
							{
								var r = results[i];
								html += '<div class="item">' +
									'<i class="search outline icon"></i>' +
									'<div class="content">' +
									'<a class="header" href="' + r.url + '" target="_blank">' + r.name+ '</a>' +
									'<div class="description">' + r.desc +'</div>' +
									'</div>' +
									'</div>';
							}

							if(html === '') {
								html = "No results found";
							}

							$("#help_search_results").html(html);

							$dimmer.addClass("disabled").removeClass("active");
						}
					);
				},
				300
			);
		}
	);

	var currentDebugSessionId = -1;
	var markers = [];
	$(".debug_step_in_button").click(function() 
	{
		$.post('/debug/step_in', {"id": currentDebugSessionId, "source": currentEditor.getValue() }, function(result) 
		{
			// Check every one second for changes
			var markDebugRanges = function() {
				$.post('/debug/status', { "id": result.id }, function(result) {
					var doc = currentEditor.getDoc();

					// Clear old debug ranges
					var i;
					for(i in markers) {
						markers[i].clear();
					}
					markers = [];

					for(i in result.ranges) {
						var r = result.ranges[i];
						//currentEditor.getDoc().setCursor(result.line, result.start);
						var marker = currentEditor.markText(
							{line: r.line, ch: r.start},
							{line: r.line, ch: r.end},
							{ className: "active-debug-range" }
						);

						// Add marker...
						markers.push(marker);
					}

					// Display output
					currentOutputEditor.setValue(result.stderr + result.stdout);

					// Store debug session id for later usage
					currentDebugSessionId = result.id;

					// Make sure marked text is shown
					currentEditor.refresh();

					console.warn(currentDebugSessionId);
					if(currentDebugSessionId > -1) {
						setTimeout(markDebugRanges, 1000);
					}
				});

			};

			markDebugRanges();
		});
		
	});

	$(".debug_step_out_button").click(function() {
		$.post('/debug/step_out', {"id": currentDebugSessionId, "source": currentEditor.getValue() }, function(result) 
		{
			// Check every one second for changes
			var markDebugRanges = function() {
				$.post('/debug/status', { "id": result.id }, function(result) {
					var doc = currentEditor.getDoc();

					// Clear old debug ranges
					var i;
					for(i in markers) {
						markers[i].clear();
					}
					markers = [];

					for(i in result.ranges) {
						var r = result.ranges[i];
						//currentEditor.getDoc().setCursor(result.line, result.start);
						var marker = currentEditor.markText(
							{line: r.line, ch: r.start},
							{line: r.line, ch: r.end},
							{ className: "active-debug-range" }
						);

						// Add marker...
						markers.push(marker);
					}

					// Display output
					currentOutputEditor.setValue(result.stderr + result.stdout);

					// Store debug session id for later usage
					currentDebugSessionId = result.id;

					// Make sure marked text is shown
					currentEditor.refresh();

					console.warn(currentDebugSessionId);
					if(currentDebugSessionId > -1) {
						setTimeout(markDebugRanges, 1000);
					}
				});

			};

			markDebugRanges();
		});
		
	});

	$(".debug_resume").click(function() {
		$.post('/debug/resume', {"id": currentDebugSessionId, "source": currentEditor.getValue() }, function(result) 
		{
			// Check every one second for changes
			var markDebugRanges = function() {
				$.post('/debug/status', { "id": result.id }, function(result) {
					var doc = currentEditor.getDoc();

					// Clear old debug ranges
					var i;
					for(i in markers) {
						markers[i].clear();
					}
					markers = [];

					for(i in result.ranges) {
						var r = result.ranges[i];
						//currentEditor.getDoc().setCursor(result.line, result.start);
						var marker = currentEditor.markText(
							{line: r.line, ch: r.start},
							{line: r.line, ch: r.end},
							{ className: "active-debug-range" }
						);

						// Add marker...
						markers.push(marker);
					}

					// Display output
					currentOutputEditor.setValue(result.stderr + result.stdout);

					// Store debug session id for later usage
					currentDebugSessionId = result.id;

					// Make sure marked text is shown
					currentEditor.refresh();

					console.warn(currentDebugSessionId);
					if(currentDebugSessionId > -1) {
						setTimeout(markDebugRanges, 1000);
					}
				});

			};

			markDebugRanges();
		});
		
	});

	$(".debug_stop_button").click(function() {
		$.post('/debug/stop', {"id": currentDebugSessionId }, function(result)
		{
			// Clear old debug ranges
			var i;
			for(i in markers) {
				markers[i].clear();
			}
			markers = [];

			// Kill current debugging session
			currentDebugSessionId = -1;
		});
	});

	$(".run_tests_button").click(function() {
		$.post('/run_tests', {}, function(result)
		{
			// Display output
			currentOutputEditor.setValue(result.output);
			colorANSI(currentOutputEditor, result.ranges);
		});
	});

	$(".trim_trailing_whitespace_button").click(function() {

		var $dimmer = $("#" + current.editorId).closest(".ui.segment").find(".dimmer");
		$dimmer.addClass("active").removeClass("disabled");

		$.post('/trim_trailing_whitespace', {"source": currentEditor.getValue()}, function(result)
		{
			if(result.changed) {
				var cursor = currentEditor.getCursor();
				currentEditor.getDoc().setValue(result.output);
				currentEditor.setCursor(cursor);
			}

			$dimmer.removeClass("active").addClass("disabled");
		});
	});

}
};

// Start Farabi when the document loads
$(function() {
	Farabi.start();
});
