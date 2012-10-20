use v6;

my $CRLF = "\x0D\x0A";
my $host = 'rosettacode.org';
my $port = 80;
my $payload = "format=json&action=query&cmtitle=Category%3APerl&cmlimit=max&list=categorymembers";
my $req = "POST /mw/api.php HTTP/1.0{$CRLF}" ~
"Host: {$host}{$CRLF}" ~
"Content-Length: {$payload.chars}{$CRLF}" ~ 
"Content-Type: application/x-www-form-urlencoded{$CRLF}{$CRLF}{$payload}"; 

my $client = IO::Socket::INET.new( :$host, :$port );
$client.send( $req );
my $response = '';
while (my $buffer = $client.recv) {
	$response ~= $buffer;
}
$client.close;

my $http_body;
my $json = '';
for $response.lines -> $line {
	
	if ($http_body) {
		$json ~= $line;
	} elsif ($line.chars == 1) {
		$http_body = 1;
		say "Found HTTP Body";
	}
}

use JSON::Tiny;
my %o = from-json($json);
my $members = %o{'query'}{'categorymembers'};
for @$members -> $member {
	say $member{'title'};
}
