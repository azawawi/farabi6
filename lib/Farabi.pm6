use v6;

module Farabi;

method run {
	require HTTP::Server::Simple;
	my $server = HTTP::Server::Simple->new(3000);
	$server->run;
}
