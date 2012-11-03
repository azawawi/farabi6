/**
 * Starts Farabi... :)
 */
function startFarabi(editorId) {

	// Cache dialog jQuery references for later use
	var $aboutDialog       = $('#about_dialog');
	var $helpDialog        = $("#help_dialog");
	var $openFileDialog    = $("#open_file_dialog");
	var $optionsDialog     = $("#options_dialog");
	var $syntaxCheckButton = $(".syntax_check_button");
	var $updatePodButton   = $(".update_pod_button");
	var $podDialog         = $("#pod_dialog");

	$("#theme_selector").change(function() {
		var $selectedTheme = $(":selected", this);
		var theme = $selectedTheme.val();

		$("head").append("<link>");
		var css = $("head").children(":last");
		css.attr({
			rel:  "stylesheet",
			type: "text/css",
			href: "assets/codemirror/theme/" + theme + ".css"
		});

		editor.setOption("theme", theme);
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
		CodeMirror.modeURL = "assets/codemirror/mode/%N.js";
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

	var editor = CodeMirror.fromTextArea(document.getElementById(editorId), {
		lineNumbers: true,
		matchBrackets: true,
		tabSize: 4,
		indentUnit: 4,
		indentWithTabs: true,
		extraKeys: {
			"F1": function(cm) {
				displayHelp(cm);
			},
			"F5": function(cm) {
				$(".run_in_browser_button").click();
			},
			"F6": function(cm) {
				$syntaxCheckButton.click();
			},
			"Ctrl-O": function(cm) {
				$(".open_file_button").click();
			},
			"Ctrl-S": function(cm) {
				$(".save_file_button").click();
			},
			"Alt-F": function(cm) {
				$('#file-dropdown').dropdown('toggle');	
			},
			"Alt-B": function(cm) {
				$('#build-dropdown').dropdown('toggle');
			},
			"Alt-T": function(cm) {
				$('#tools-dropdown').dropdown('toggle');
			},
			"Alt-H": function(cm) {
				$('#help-dropdown').dropdown('toggle');
			}
		}
	});

	editor.on('focus', function(cm) {
		$('.dropdown.open').dropdown('toggle');
	});

	// Hook up with cursor activity event
	editor.on("cursorActivity", function(cm) {
			// Highlight current line
			cm.setLineClass(hlLine, null, null);
			hlLine = cm.setLineClass(cm.getCursor().line, null, "activeline");

			// Highlight selection matches
			cm.matchHighlight("CodeMirror-matchhighlight");

			// Show editor statistics
			showEditorStats(cm);
	});

	// Run these when we exit this one
	setTimeout(function() {
		// Editor is by default Perl
		changeMode(editor, 'perl6');

		// focus!
		editor.focus();

		// Show editor stats at startup
		showEditorStats(editor);

	}, 0);

	// Highlight current line
	var hlLine = editor.setLineClass(0, "activeline");

	$(".results").hide();

	var perl6mode = 1;  //TODO should be depending on mode mimetype
	$(".run_in_browser_button").click(function() {
		if(perl6mode) {
			if(typeof p6pkg != 'undefined') {
                                runOnPerlito6(editor.getValue());
                        } else {
                                // Load Perlito and then run
                                $.ajax({
                                        url: 'assets/perlito/perlito6.min.js',
                                        dataType: "script",
                                        success: function() {
                                                runOnPerlito6(editor.getValue());
                                        }
                                });
                        }
		} else {
			if(typeof p5pkg != 'undefined') {
				runOnPerlito5(editor.getValue());
			} else {
				// Load Perlito and then run
				$.ajax({
					url: 'assets/perlito/perlito5.min.js',
					dataType: "script",
					success: function() {
						runOnPerlito5(editor.getValue());
					}
				});
			}
		}
	});

	$("#file", $openFileDialog).keypress(function() {
		var filename = $("#file", $openFileDialog);
		$.ajax({
			url:     "/search_file",
			data:    { "filename": filename },
			success: function(results) {
				console.warn(results);
			},
			error:   function(jqXHR, textStatus, errorThrown) {
				console.error("Error!" + textStatus + ", " + errorThrown);
			}
		});
	});

	$("#ok-button", $openFileDialog).click(function() {
		var filename = $("#file", $openFileDialog);
		if (!filename) {
			return;
		}
		$.ajax({

			url:     "/open_file",
			data:    { "filename": filename },
			success: function(code) {
				editor.setValue(code);
			},
			error:   function(jqXHR, textStatus, errorThrown) {
				console.error("Error!" + textStatus + ", " + errorThrown);
			}
		});
	});

	$(".open_file_button").click(function() {
		$openFileDialog.modal('show');
		$("#file", $openFileDialog).focus();
	});

	$(".save_file_button").click(function() {
		console.warn("TODO implement Save file clicked");	
	});

	$(".save_as_file_button").click(function() {
		var filename = prompt("File name to save as?");
		if(!filename) {
			return;
		}
		$.get("/save_as_file",
             { "filename": filename },
             function() {
    			alert("Save as worked?!");
             }
         );
	});

	$(".open_url_button").click(function() {
		var url = prompt("Please Enter a http/https file location:" + 
			"\ne.g https://raw.github.com/ihrd/uri/master/lib/URI.pm");
		if(!url) {
			return;
		}
		$.get('/open_url',
        	{ "url": url },
           	function(code) {
            	editor.setValue(code);
            }
        );
	});

	var $output = $("#output");

	var syntaxCheckWidgets = [];
	var syntaxCheck = function(cm) {

		$.get('/syntax_check', {"source": cm.getValue() }, function(result) {
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
				$output.val(result.output);
			}
		});
	};

	$('.about_button').click(function() {
		if(typeof p5pkg == 'undefined') {
			$.ajax({
				url: 'assets/perlito/perlito5.min.js',
				dataType: "script",
				cache: true,
				success: function() {
					$('#perlito-version').html(  p5pkg[ "main" ][ "v_]"]);
				}
			});
		} else {
			$('#perlito-version').html(p5pkg[ "main" ][ "v_]" ]);
		}
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

	var onCloseFocusEditor = function () {
		editor.focus();
	};
	$aboutDialog.hide().on('hidden', onCloseFocusEditor);
	$helpDialog.hide().on('hidden', onCloseFocusEditor);
	$openFileDialog.hide().on('hidden', onCloseFocusEditor);
	$optionsDialog.hide().on('hidden', onCloseFocusEditor);
	$podDialog.hide().on('hidden', onCloseFocusEditor);

	$("#line_numbers_checkbox").change(function() {
		editor.setOption('lineNumbers', $(this).is(':checked'));
	});

	$syntaxCheckButton.click(function() {
		syntaxCheck(editor);
	});
	$updatePodButton.click(function() {
		$.get('/pod_to_html', 
			{ "source": editor.getValue() }, 
			function(html) {
				$('.modal-body', $podDialog).html(html);
				$podDialog.modal('show');
			}
		);
	});


	$("#tab_size").change(function() {
		var tabSize = $(this).val();
		if($.isNumeric(tabSize)) {
			$(this).parent().parent().removeClass("error");
			editor.setOption('tabSize', tabSize);
		} else {
			$(this).parent().parent().addClass("error");
		}
	});
}

function runOnPerlito6(source) {
	var $output = $('#output');
	window.print = function(s) {
		$output.val($output.val() + s + "\n");
	}
        var ast;
	var match;
	$output.val('');
	try {
                // compilation unit
                match = Perlito6$Grammar.exp_stmts(source, 0);
                ast = match.scalar();
                tmp = {v_name:"GLOBAL", v_body: ast}; 
                tmp.__proto__ = CompUnit; 
                ast = tmp;
		eval(ast.emit_javascript());
	} catch(err) {
                // Show error in output tab
                $output.val("Error:\n" + perl(err) + "\nCompilation aborted.\n");
	}

        // Show output tab
        $('a[href="#output-tab"]').tab('show');

}

function runOnPerlito5(source) {

	var $output = $('#output');

	// CORE.print prints to output tab
	p5pkg.CORE.print = function(List__) {
		var i;
		for (i = 0; i < List__.length; i++) {
			$output.val( $output.val() + p5str(List__[i]));
		}
		return true;
	};

	// CORE.warn print to output tab
	p5pkg.CORE.warn = function(List__) {
		var i;
		List__.push("\n");
		for (i = 0; i < List__.length; i++) {
			$output.val( $output.val() + p5str(List__[i]));
		}
		return true;
	};

	// Define version, strict and warnings
	p5pkg["main"]["v_^O"] = "browser";
	p5pkg["main"]["Hash_INC"]["Perlito5/strict.pm"] = "Perlito5/strict.pm";
	p5pkg["main"]["Hash_INC"]["Perlito5/warnings.pm"] = "Perlito5/warnings.pm";

	p5make_sub("Perlito5::IO", "slurp", function(filename) {
		console.error('IO.slurp "' + filename + '"');
		return 1;
	});

	p5is_file = function(filename) {
		console.error('p5is_file "' + filename + '"');
		return 1;
	}

	// Clear up output
	$output.val('');

	try {
		// Compile and run!
		eval(p5pkg["Perlito5"].compile_p5_to_js([source]));

	}
	catch(err) {
		// Populate error and show error in output tab
		$output.val("Error:\n" + err + "\nCompilation aborted.\n");
	}

	// Show output tab
	$('a[href="#output-tab"]').tab('show');

}

// Start Farabi when the document loads
$(function() {
	startFarabi("editor");
});
