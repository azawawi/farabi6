use v6;

class Farabi6;

method run {
	use HTTP::Server::Simple;
	my $server = HTTP::Server::Simple.new(3000);
	$server.run;
}
