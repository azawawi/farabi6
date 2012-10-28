use v6;

# External
use File::Spec;
use HTTP::Easy::PSGI;
use JSON::Tiny;
use URI::Escape;
use URI;

class Farabi6;

=begin pod

Runs the Farabi webserver at host:port. If host is empty
then it listens on all interfaces

=end pod
method run(Str $host, Int $port) {
	
	my @dirs = File::Spec.splitdir($?FILE);
	my $files-dir = File::Spec.catdir(@dirs[0..*-2], 'Farabi6', 'files');
	unless (File::Spec.catdir($files-dir, 'farabi.js').IO ~~ :e) {
		# Workaround for panda not installing non-perl files in ~/.perl6
		$files-dir = File::Spec.catdir(%*ENV{'HOME'}, '.panda', 'src', 'Farabi6', 'lib', 'Farabi6', 'files');	
		say "Panda installation found. Switching to {$files-dir}";
	}

	# Make sure files contains farabi.js
	die "farabi.js is not found in {$files-dir}" 
		unless (File::Spec.catdir($files-dir, 'farabi.js').IO ~~ :e);

	say "Farabi6 is going to serve files *insecurely* from {$files-dir} :)";
	
	say "Farabi6 listens carefully at http://$host:$port";
	my $http = HTTP::Easy::PSGI.new(:$host, :$port);
	my $app = sub (%env)
	{
		my Str $filename;
   		my Str $uri = %env<REQUEST_URI>;
		$uri ~~= s/\?.*$//;
		
		# Handle files and routes :)
		if ($uri eq '/') {
			$filename = 'index.html';
		} elsif ($uri eq '/pod_to_html') { 
			return self.pod-to-html(self.get-parameter(%env<psgi.input>, 'source'));
		} elsif ($uri eq '/syntax_check') {
			return self.syntax-check(self.get-parameter(%env<psgi.input>, 'source')); 
		} elsif ($uri eq '/open_url') {
			return self.open-url(self.get-parameter(%env<psgi.input>, 'url'));
		} elsif ($uri eq '/rosettacode_rebuild_index') {
			return self.rosettacode-rebuild-index;
		} elsif ($uri eq '/rosettacode_search') {
			return self.rosettacode-search(self.get-parameter(%env<psgi.input>, 'something'));
		} else {
			$filename = $uri.substr(1);
		}

		# Get the real file from the local filesystem
		#TODO more robust and secure way of getting files. We could easily be attacked from here
		$filename = File::Spec.catdir($files-dir, $filename);
		my Str $mime-type = self.find-mime-type($filename);
	
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
 	$http.handle($app);

}



