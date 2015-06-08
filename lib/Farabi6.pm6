use v6;

class Farabi6 {

# External
use HTTP::Easy::PSGI;
use URI;
use Browser::Open;

# Internal
use Farabi6::Editor;
use Farabi6::Util;

=begin pod

Runs the Farabi webserver at host:port. If host is empty
then it listens on all interfaces

=end pod
method run(Str $host, Int $port, Bool $verbose) is export {

	if $verbose {
		EVAL q:to/END/;
			# Ctrl-C handler only works on moar-based perl6
			say "Enabling Ctrl-C handler. This may cause high CPU usage";
			signal(SIGINT).tap({
				"Ctrl-C detected".say;
				die
			});
		END

		CATCH {
			when X::Comp { say "Ctrl-C handler only works on moar-based perl6" }
		}
	}

	my $files-dir = 'lib/Farabi6/files';
	unless "$files-dir/assets/farabi.js".IO ~~ :e {
		say "Switching to panda-installed farabi6";

		# Find farabi.js in @*INC
		for @*INC -> $f {
			my $root-dir = $*SPEC.catdir($f, 'Farabi6', 'files');
			if $*SPEC.catdir( $root-dir, 'assets', 'farabi.js' ).IO ~~ :e {
				$files-dir = $root-dir;
				last;
			}
		}

		# Workaround to 'C:rakudo' catdir bug under win32
		if $*DISTRO.name eq 'mswin32' {
			$files-dir = $files-dir.subst(/ :i (<[a..z]> ':') <![\\]>/, {$0 ~ '\\'});
		}

		say "Found Farabi6 root dir @ $files-dir after looping on @*INC";
	}

	# Make sure files contains farabi.js
	die "farabi.js is not found in {$files-dir}/assets" 
		unless $*SPEC.catdir($files-dir, 'assets', 'farabi.js').IO ~~ :e;

	say "Farabi6 is serving files from {$files-dir} at http://$host:$port";
	my $app = sub (%env)
	{
   		return [400,['Content-Type' => 'text/plain'],['']] if %env<REQUEST_METHOD> eq '';
		
		my Str $filename;
		my Str $uri = %env<REQUEST_URI>;

		# Remove the query string part
		$uri ~~ s/ '?' .* $ //;

		# Handle files and routes :)
		my %params = Farabi6::Util.params(%env<psgi.input>);

		given $uri {
			when '/' {
				$filename = 'index.html';
			}
			when /^ '/assets/' / {
				$filename = $uri.substr(1);
			}
			when '/pod_to_html' {
				return Farabi6::Editor.pod-to-html(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source'));
			}
			when '/syntax_check' {
				return Farabi6::Editor.syntax-check(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source'));
			}
			when '/open_file' {
				return Farabi6::Editor.open-file(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'filename'));
			}
			when '/search_file' {
				return Farabi6::Editor.search-file(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'filename'));
			}
			when '/open_url' {
				return Farabi6::Editor.open-url(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'url'));
			}
			when '/rosettacode_rebuild_index' {
				return Farabi6::Editor.rosettacode-rebuild-index;
			}
			when '/rosettacode_search' {
				return Farabi6::Editor.rosettacode-search(
					Farabi6::Util.get-parameter(%env<psgi.input>, 'something'));
			}
			when '/run/rakudo' {
				return Farabi6::Editor.run-code(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source'));
			}
			when '/run_tests' {
				return Farabi6::Editor.run-tests;
			}
			when '/trim_trailing_whitespace' {
				return Farabi6::Editor.trim-trailing-whitespace(%params<source>);
			}
			when '/eval_repl_expr' {
				return Farabi6::Editor.eval-repl-expr(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'expr'));
			}
			when '/profile/rakudo' {
				return Farabi6::Editor.run-code(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source'),
					'--profile');
			}
			when '/module/search' {
				return Farabi6::Editor.module-search(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'pattern'));
			}
			when '/git/diff' {
				return Farabi6::Editor.run-command('git diff --color');
			}
			when '/git/log' {
				return Farabi6::Editor.run-command('git log --color');
			}
			when '/git/status' {
				return Farabi6::Editor.run-command('git status');
			}
			when '/help/search' {
				return Farabi6::Editor.help-search(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'pattern'));
			}
			when '/debug/status' {
				return Farabi6::Editor.debug-status(
					Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'id')
				);
			}
			when '/debug/step_in' {
				return Farabi6::Editor.debug-step-in(
					%params<id>,
					%params<source>
				);
			}
			when '/debug/step_out' {
				return Farabi6::Editor.debug-step-out(
					%params<id>,
					%params<source>
				);
			}
			when '/debug/resume' {
				return Farabi6::Editor.debug-resume(
					%params<id>,
					%params<source>
				);
			}
			when '/debug/stop' {
				return Farabi6::Editor.debug-stop(
					%params<id>
				);
			}
			when '/profile/results' {
				# Return profile HTML results if found
				my $id = $/[0].Str if %env<QUERY_STRING> ~~ /^id\=(.+)$/;
				return Farabi6::Editor.profile-results($id);
			}
			default {
				$filename = .substr(1);
			}
		}

		$filename = $*SPEC.catdir($files-dir, $filename);
		my Str $mime-type = Farabi6::Util.find-mime-type($filename);

		my Int $status;
		my $contents;
		if ($filename.IO ~~ :e) {
			$status = 200;
			$contents = $filename.IO.slurp(:bin);
		} 

		unless ($contents) {
			$status = 404;
			$mime-type = 'text/plain';
			$contents = "Not found $uri";	
		}
		
		[ 
			$status, 
			[ 'Content-Type' => $mime-type ], 
			[ $contents ] 
		];
	}

	start {
		# Give the server some time to start up
		sleep 1;

		# Open the farabi6 website in your browser
		my $url = "http://$host:$port";
		say "Trying to open $url in your default browser";
		open_browser($url);
	}

	my $server = HTTP::Easy::PSGI.new(:host($host), :port($port), :debug($verbose));
	$server.app($app);
 	$server.run;
}


}
