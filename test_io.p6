use v6;

use URI;
use URI::Escape;
use JSON::Tiny;

sub post-request($url, $payload) {
	constant $CRLF = "\x0D\x0A";

	my $o = URI.new($url);
	my $host = $o.host;
	my $port = $o.port;
	my $req = "POST {$o.path} HTTP/1.0{$CRLF}" ~
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
	my $body = '';
	for $response.lines -> $line {
	
		if ($http_body) {
			$body ~= $line;
		} elsif ($line.chars == 1) {
			$http_body = 1;
			say "Found HTTP Body";
		}
	}

	$body;
}

my $language = "Python";
my $escaped-title = uri_escape("Category:Perl 6");
my $json = post-request(
        'http://rosettacode.org/mw/api.php',
        "format=json&action=query&cmtitle={$escaped-title}&cmlimit=max&list=categorymembers"
);

my %o = from-json($json);
my $members = %o{'query'}{'categorymembers'};
for @$members -> $member {
	say $member{'title'};
}
