use v6;
use HTTP::Easy::PSGI;

class Farabi6;

method run($port) {
	my $http = HTTP::Easy::PSGI.new(:port($port));
	my $app = sub (%env)
	{
		my Str $filename;
   		my Str $uri = %env<REQUEST_URI>;
		if ($uri eq '/') {
			$filename = 'index.html';
		} else {
			$filename = $uri.substr(1);
		}
		$filename = "lib/Farabi6/files/$filename";
		my Int $status;
		my Str $mime-type;
		my Str $content;
		if ($filename.IO ~~ :e) {
			if (my $fh = open $filename ) {
				$status = 200;
				$content = $fh.slurp;
				$fh.close;
			}
		} 


		if ($filename ~~ /\.html$/) {
			$mime-type = 'text/html';
		} elsif ($filename ~~ /\.css$/) {
			$mime-type = 'text/css';
		} elsif ($filename ~~ /\.js$/) {
			$mime-type = 'text/javascript';
		} else {
			say "Cannot handle $filename";
		}

		if (!$content) {
			$status = 404;
			$mime-type = 'text/plain';
			$content = "Not found $uri";	
		}
		return [ 
			$status, 
			[ 'Content-Type' => $mime-type ], 
			[ $content ] 
		];
	}
 	$http.handle($app);

}

