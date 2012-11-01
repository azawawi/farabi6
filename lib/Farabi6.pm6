use v6;

class Farabi6 {

# External
use File::Spec;
use HTTP::Server::Simple::PSGI;
use URI;

# Internal
use Farabi6::Editor;
use Farabi6::Util;

=begin pod

Runs the Farabi webserver at host:port. If host is empty
then it listens on all interfaces

=end pod
method run(Str $host, Int $port) is export {
	
	my @dirs = File::Spec.splitdir($?FILE);
	my $files-dir = File::Spec.catdir(@dirs[0..*-2], 'Farabi6', 'files');
	unless File::Spec.catdir($files-dir, 'farabi.js').IO ~~ :e {
		# Workaround for panda not installing non-perl files in ~/.perl6
		$files-dir = File::Spec.catdir(
			%*ENV{'HOME'}, '.panda', 'src', 'Farabi6', 'lib', 'Farabi6', 'files');	
		say "Panda installation found. Switching to {$files-dir}";
	}

	# Make sure files contains farabi.js
	die "farabi.js is not found in {$files-dir}" 
		unless File::Spec.catdir($files-dir, 'farabi.js').IO ~~ :e;

	say "Farabi6 is serving files from {$files-dir} at http://$host:$port";
	my $app = sub (%env)
	{
		my Str $filename;
   		my Str $uri = %env<REQUEST_URI>;
		$uri ~~= s/\?.*$//;

		#TODO use psgi.input once HTTP::Server::Simple supports it
	
		# Handle files and routes :)
		if ($uri eq '/') {
			$filename = 'index.html';
		} elsif ($uri eq '/pod_to_html') { 
			return Farabi6::Editor.pod-to-html(
				Farabi6::Util.get-parameter(%env<QUERY_STRING>, 'source'));
		} elsif ($uri eq '/syntax_check') {
			return Farabi6::Editor.syntax-check(
				Farabi6::Util.get-parameter(%env<QUERY_STRING>, 'source')); 
		} elsif ($uri eq '/open_file') {
			return Farabi6::Editor.open-file(
				Farabi6::Util.get-parameter(%env<QUERY_STRING>, 'filename')); 
		} elsif ($uri eq '/open_url') {
			return Farabi6::Editor.open-url(
				Farabi6::Util.get-parameter(%env<QUERY_STRING>, 'url'));
		} elsif ($uri eq '/rosettacode_rebuild_index') {
			return Farabi6::Editor.rosettacode-rebuild-index;
		} elsif ($uri eq '/rosettacode_search') {
			return Farabi6::Editor.rosettacode-search(
				Farabi6::Util.get-parameter(%env<QUERY_STRING>, 'something'));
		} else {
			$filename = $uri.substr(1);
		}

		# Get the real file from the local filesystem
		#TODO more robust and secure way of getting files. We could easily be attacked from here
		$filename = File::Spec.catdir($files-dir, $filename);
		my Str $mime-type = Farabi6::Util.find-mime-type($filename);
		my Int $status;
		my $contents;
		if ($filename.IO ~~ :e) {
			if (my $fh = open $filename, :bin ) {
				$status = 200;
				$contents = $fh.slurp;
				$fh.close;
			}
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

	my $server = HTTP::Server::Simple::PSGI.new($port);
	$server.host = $host;
	$server.app($app);
 	$server.run;
}


}
