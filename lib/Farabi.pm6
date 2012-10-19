use v6;

class Farabi;

use HTTP::Server::Simple;

method run {
	require HTTP::Server::Simple;
	my $server = HTTP::Server::Simple->new(3000);
	$server->run;
}
