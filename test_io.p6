use v6;

my $CRLF = "\x0A\x0D";
my $host = 'rosettacode.org';
my $port = 80;
my $req = "POST /mw/api.php HTTP/1.1$CRLF" ~
	"Host: $host$CRLF" ~
	"Content-Length: 81$CRLF" ~ 
	"Content-Type: application/x-www-form-urlencoded$CRLF$CRLF" ~
	"format=json&action=query&cmtitle=Category%3APerl&cmlimit=max&list=categorymembers";
my $client = IO::Socket::INET.new( :$host, :$port );
$client.send( $req );
my $response = '';
while (my $buffer = $client.recv) {
	$response ~= $buffer;
}
$client.close;

say $response;
