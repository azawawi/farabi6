use v6;

class Farabi6 {

# External
use HTTP::Easy::PSGI;
use URI;

# Internal
use Farabi6::Editor;
use Farabi6::Util;

=begin pod

Runs the Farabi webserver at host:port. If host is empty
then it listens on all interfaces

=end pod
method run(Str $host, Int $port) is export {
	
	# Trap Ctrl-C to properly execute END { } to enable
	# showing of deprecated messages
	signal(SIGINT).tap({
		"Ctrl-C detected".say;
		die
	});

	# Development or panda-installed farabi6?
	my $files-dir = 'lib/Farabi6/files';
	unless "$files-dir/assets/farabi.js".IO ~~ :e {
		say "Switching to panda-installed farabi6";
		my @dirs = $*SPEC.splitdir($*EXECUTABLE);
		$files-dir = $*SPEC.catdir(
			@dirs[0..*-3], 
			'languages', 'perl6', 'site', 'lib', 'Farabi6', 'files'
		);
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
		$uri ~~= s/\?.*$//;

		# Handle files and routes :)
		if $uri eq '/' {
			$filename = 'index.html';
		} elsif $uri eq '/pod_to_html' { 
			return Farabi6::Editor.pod-to-html(
				Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source'));
		} elsif $uri eq '/syntax_check' {
			return Farabi6::Editor.syntax-check(
				Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source')); 
		} elsif $uri eq '/open_file' {
			return Farabi6::Editor.open-file(
				Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'filename')); 
		} elsif $uri eq '/search_file' {
			return Farabi6::Editor.search-file(
				Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'filename')); 
		} elsif $uri eq '/open_url' {
			return Farabi6::Editor.open-url(
				Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'url'));
		} elsif $uri eq '/rosettacode_rebuild_index' {
			return Farabi6::Editor.rosettacode-rebuild-index;
		} elsif $uri eq '/rosettacode_search' {
			return Farabi6::Editor.rosettacode-search(
				Farabi6::Util.get-parameter(%env<psgi.input>, 'something'));
		} elsif $uri eq '/run/rakudo' {
			return Farabi6::Editor.run-code(
				Farabi6::Util.get-parameter(%env<psgi.input>.decode, 'source'),
				'rakudo'); 		
		} else {
			$filename = $uri.substr(1);
		}

		# Get the real file from the local filesystem
		#TODO more robust and secure way of getting files. We could easily be attacked from here
		$filename = $*SPEC.catdir($files-dir, $filename);
		my Str $mime-type = Farabi6::Util.find-mime-type($filename);
		my Int $status;
		my $contents;
		if ($filename.IO ~~ :e) {
			$status = 200;
			$contents = slurp $filename, :enc('ASCII');
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

	my $server = HTTP::Easy::PSGI.new(:host($host), :port($port));
	$server.app($app);
 	$server.run;
}


}
