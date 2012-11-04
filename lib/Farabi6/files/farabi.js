/**
 * Starts Farabi... :)
 */
function startFarabi(editorId) {

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
				$(".run-button").click();
			},
			"F6": function(cm) {
				$syntaxCheckButton.click();
			},
			"F9": function(cm) {
				$showPodButton.click();
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

	$runButton.click(function() {
		
		$runDialog.modal('show');
		$("#runtime", $runDialog).focus().change();
	});

	$("#runtime").keypress(function(evt) {
		if(evt.keyCode == 13) {
			$("#ok-button", $runDialog).click();
		}
	});

	var runtimeHelp = {
		"rakudo"    : {
			text    : "<b>Rakudo</b> Perl 6, or simply Rakudo, is a compiler for the Perl 6 programming language. It runs on the Parrot virtual machine.",
			url     : "http://rakudo.org/about",
		},
		"niecza"    : {
			text    : "<b>Niecza</b> is a Perl 6 implementation focusing on optimization and efficient implementation research. It targets the Common Language Runtime (<a href='http://en.wikipedia.org/wiki/Common_Language_Infrastructure' target='_blank'>ECMA-335</a>; implementations are 'Mono' and '.NET').",
			url     : "https://github.com/sorear/niecza/blob/master/README.pod",
		},	
		"perlito-6" : {
			text    : "<b>Perlito 6</b> is a compiler collection that implements a subset of Perl 6.",
			url     : "http://perlito.org",
		},
		"perlito-5" : {
			text    : "<b>Perlito 5</b> is a compiler collection that implements a subset of Perl 5.",
			url     : "http://perlito.org",
		},
	};

	$("#runtime").change(function() {
		var runtime = $(":selected", $(this)).attr('id');
		var help = runtimeHelp[runtime];
		$("#help", $runDialog).html(help.text + "<br><a href='" + help.url + "' target='_blank'>More information...</a>");
	});

	$("#ok-button", $runDialog).click(function() {
			
		var runtime = $("#runtime :selected", $runDialog).attr('id');
		if(runtime == "perlito-6") {
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
		} else if(runtime == "perlito-5") {
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

	var searchFile = function() {
		var filename = $("#file", $openFileDialog).val();
		$("#search-results", $openFileDialog).empty();
		$("#ok-button", $openFileDialog).attr("disabled","disabled");
		$.ajax({
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
	}

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

	// Hide and setup the on-hide-focus-the-editor event
	$(".modal").hide().on('hidden', function() {
		editor.focus();
	});

	$("#line_numbers_checkbox").change(function() {
		editor.setOption('lineNumbers', $(this).is(':checked'));
	});

	$syntaxCheckButton.click(function() {
		syntaxCheck(editor);
	});
	$showPodButton.click(function() {
		$.get('/pod_to_html', 
			{ "source": editor.getValue() }, 
			function(html) {
				$('.modal-body', $podDialog).html(html);
				$podDialog.modal('show');
			}
		);
	});

	$runButton.click(function() {
		
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
