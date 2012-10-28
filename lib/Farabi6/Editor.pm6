package Farabi6;

class Editor;

=begin comment

Syntax checks the current editor document for any problems using
std/viv

=end comment
method syntax-check(Str $source) {

	# TODO use File::Temp once it is usable
	my $filename = File::Spec.catfile(File::Spec.tmpdir, 'farabi-syntax-check.tmp');
	my $fh = open $filename, :w;
	$fh.print($source);
	$fh.close;	

	#TODO more portable version for win32 in the future
	my Str $viv = File::Spec.catdir(%*ENV{'HOME'}, 'std', 'viv');
    my Str $output = qqx{$viv -c $filename};

	my @problems;
	for $output.lines -> $line {
		if ($line ~~ /^(.+)\ at\ .+\ line\ (\d+)\:$/ ) {
			push @problems, {
				'description'   => ~$0,
				'line_number'   => ~$1,
			}
		}
	}

	my %result = 
		'problems' => @problems,
		'output'   => $output;

	[
		200,
		[ 'Content-Type' => 'application/json' ],
        [ to-json(%result) ],
	];
}

method get-parameter(Buf $input, $name) {
	# TODO more generic parameter parsing
	my $value =  $input.decode;
	$value ~~ s/^$name\=//;
	uri_unescape($value);
}

=begin comment

Returns a PSGI response that contains the contents of the URL
provided

=end comment
method open-url($url) {
	[
		200,
        [ 'Content-Type' => 'text/plain' ],
        [ self.http-get($url) ],
	];
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

=begin comment

Returns a PSGI response containing a rendered POD HTML string

=end comment
method pod-to-html(Str $pod) {

	# TODO use File::Temp once it is usable
	my $filename = File::Spec.catfile(File::Spec.tmpdir, 'farabi-pod-to-html.tmp');
	my $fh = open $filename, :w;
	$fh.print($pod);	
	$fh.close;
	
	my $contents = qqx/perl6 --doc=HTML $filename/;
	$contents ~~ s/^.+\<body.+?\>(.+)\<\/body\>.+$/$0/;
	
	# TODO more robust cleanup
	unlink $filename;

	[
		200,
		[ 'Content-Type' => 'text/plain' ],
		[ $contents ],
	];
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

method rosettacode-rebuild-index(Str $language) {

	my $escaped-title = uri_escape("Category:{$language}");
	my $json = self.post-request(
        'http://rosettacode.org/mw/api.php',
       	"format=json&action=query&cmtitle={$escaped-title}&cmlimit=max&list=categorymembers"
	);

	my $filename = 'farabi-rosettacode-cache';
	my %o = from-json($json);
	my $members = %o{'query'}{'categorymembers'};
	my $fh = open "rosettacode-index.cache", :w;
	for @$members -> $member {
		$fh.say($member{'title'});
	}
	$fh.close;
}

method rosettacode-search(Str $something) {
	...
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

