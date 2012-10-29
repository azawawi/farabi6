use v6;

class Farabi6::Util {

use URI::Escape;

method get-parameter(Buf $input, Str $name) {
	# TODO more generic parameter parsing
	my $value =  $input.decode;
	$value ~~ s/^$name\=//;
	uri_unescape($value);
}

=begin comment

This is a utility for sending a GET HTTP request. Right now
it is uses wget since it is the most reliable at this time
Both LWP::Simple and  suffers from installation and bugs

=end comment
method http-get(Str $url) {
    #TODO investigate whether LWP::Simple is installable and workable again
    #TODO investigate whether HTTP::Client after the promised big refactor works or not
	die "URL is not defined!" unless $url; 
	qqx/wget -qO- $url/;
}

#TODO use LWP::Simple.post if it works?
method post-request($url, $payload) {
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

#TODO refactor into Farabi::Types (like Mojo::Types)
method find-mime-type(Str $filename) {
	my %mime-types = ( 
		'html' => 'text/html',
		'css'  => 'text/css',
		'js'   => 'text/javascript',
		'png'  => 'image/png',
		'ico'  => 'image/vnd.microsoft.icon',
	);
	
	my $mime-type;
	if ($filename ~~ /\.(\w+)$/) {
		$mime-type = %mime-types{$0} // 'text/plain';
	} else {
		$mime-type = 'text/plain';
	}

	$mime-type;
}


}
