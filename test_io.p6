my $host = 'rosettacode.org';
my $port = 80;
my $CRLF = "\x0A\x0D";
my $client = IO::Socket::INET.new(:$host, :$port);
$client.send( "GET /wiki/RosettaCode HTTP/1.1$CRLF$CRLF" );
my $response = '';
while (my $buffer = $client.recv) {
	$response ~= $buffer;
}
say $response;
$client.close;
