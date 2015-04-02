use HTTP::Server::Async;

my $s = HTTP::Server::Async.new;

$s.register(sub ($request, $response, $next) {

	('[INFO] ' ~ $request.perl).say;
	
	say $request.uri;

	$response.headers<Content-Type> = 'text/plain';

	if $request.uri eq '/foo' {
	  $response.status = 200;
	  $response.write("/foo is here! ");
	  $response.close;
	} else {
		$response.status = 200;
		$response.write("Hello from $($request.uri)...");
		# Keeps a promise in the response and ends the server handler processing
		$response.close; 
	}

});

$s.listen;
$s.block;

say "Finished listening...";

# vim=ft perl6
