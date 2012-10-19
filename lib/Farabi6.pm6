use v6;
use HTTP::Easy::PSGI;

class Farabi6;

method run($port) {
	my $http = HTTP::Easy::PSGI.new(:port($port));
	my $app = sub (%env)
	{
		my $status = 404;
		my $content = 'Not found!';
		my $mime-type = 'text/plain';
   		my $query = %env<REQUEST_URI>;
		if ($query eq '/') {
			my $fh = open 'lib/Farabi6/files/index.html';
			($status, $mime-type, $content) = 
				(200, 'text/html', $fh.slurp);
			$fh.close;
		}
		return [ 
			$status, 
			[ 'Content-Type' => $mime-type ], 
			[ $content ] 
		];
	}
 	$http.handle($app);

}

