use v6;
use HTTP::Easy::PSGI;

class Farabi6;

method run($port) {
	my $http = HTTP::Easy::PSGI.new(:port($port));
	my $app = sub (%env)
	{
   	my $name = %env<QUERY_STRING> || "World";
   	return [ 200, [ 'Content-Type' => 'text/plain' ], [ "Hello $name" ] ];
	}

 	$http.handle($app);

}


