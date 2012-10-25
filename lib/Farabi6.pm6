use v6;

# External
use File::Spec;
use HTTP::Easy::PSGI;
use JSON::Tiny;
use URI::Escape;
use URI;

class Farabi6;

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

method run(Str $host, Int $port) {
	
	my @dirs = File::Spec.splitdir($?FILE);
	my $files-dir = File::Spec.catdir(@dirs[0..*-2], 'Farabi6', 'files');
	unless (File::Spec.catdir($files-dir, 'farabi.js').IO ~~ :e) {
		# Workaround for panda not installing non-perl files in ~/.perl6
		$files-dir = File::Spec.catdir(%*ENV{'HOME'}, '.panda', 'src', 'Farabi6', 'lib', 'Farabi6', 'files');	
		say "Panda installation found. Switching to {$files-dir}";
	}

	# Make sure files contains farabi.js
	die "farabi.js is not found in {$files-dir}" 
		unless (File::Spec.catdir($files-dir, 'farabi.js').IO ~~ :e);

	say "Farabi6 is going to serve files *insecurely* from {$files-dir} :)";
	
	say "Farabi6 listens carefully at http://$host:$port";
	my $http = HTTP::Easy::PSGI.new(:$host, :$port);
	my $app = sub (%env)
	{
		my Str $filename;
   		my Str $uri = %env<REQUEST_URI>;
		$uri = $uri ~~ s/\?.*$//;
		
		# Handle files and routes :)
		if ($uri eq '/') {
			$filename = 'index.html';
		} elsif ($uri eq '/pod_to_html') { 
			return self.pod-to-html(self.get-parameter(%env<psgi.input>, 'source'));
		} elsif ($uri eq '/syntax_check') {
			return self.syntax-check(self.get-parameter(%env<psgi.input>, 'source')); 
		} elsif ($uri eq '/open_url') {
			return self.open-url(self.get-parameter(%env<psgi.input>, 'url'));
		} elsif ($uri eq '/rosettacode_rebuild_index') {
			return self.rosettacode-rebuild-index;
		} elsif ($uri eq '/rosettacode_search') {
			return self.rosettacode-search(self.get-parameter(%env<psgi.input>, 'something'));
		} else {
			$filename = $uri.substr(1);
		}

		# Get the real file from the local filesystem
		#TODO more robust and secure way of getting files. We could easily be attacked from here
		$filename = File::Spec.catdir($files-dir, $filename);
		my Str $mime-type = self.find-mime-type($filename);
	
		my Int $status;
		my $contents;
		if ($filename.IO ~~ :e) {
			if (my $fh = open $filename, :bin ) {
				$status = 200;
				$contents = $fh.slurp;
				$fh.close;
			}
		} 
		unless ($contents) {
			$status = 404;
			$mime-type = 'text/plain';
			$contents = "Not found $uri";	
		}
		return [ 
			$status, 
			[ 'Content-Type' => $mime-type ], 
			[ $contents ] 
		];
	}
 	$http.handle($app);

}

=begin pod
Syntax checks the current editor document for any problems using
std viv
=end pod
sub syntax-check(Str $source) {
    return [
		200,
		[ 'Content-Type' => 'text/plain' ],
        [ '[]' ],
	];
}

method get-parameter(Buf $input, $name) {
	# TODO more generic parameter parsing
	my $value =  $input.decode;
	$value ~~ s/^$name\=//;
	uri_unescape($value);
}

=begin pod
Returns the contents of the URL provided from the web
=end pod
method open-url($url) {
	return [
      		200,
        	[ 'Content-Type' => 'text/plain' ],
        	[ self.http-get($url) ],
	];
}

=begin pod
This serves as a utility for getting an HTTP request
it is uses wget since it is the most reliable at this time
Both LWP::Simple and  suffers from installation and bugs
=end pod 
method http-get(Str $url) {
#TODO investigate whether LWP::Simple is installable and workable again
#TODO investigate whether HTTP::Client after the promised big refactor works or not
	die "URL is not defined!" unless $url; 
	qqx/wget -qO- $url/;
}

method pod-to-html(Buf $input) {

	# TODO more generic parameter parsing
	my $source =  $input.decode;
	$source ~~ s/^source\=//;
	$source = uri_unescape($source);

	# TODO use File::Temp once it is usable
	my $filename = File::Spec.catfile(File::Spec.tmpdir, 'farabi-pod2html.tmp');
	my $fh = open $filename, :w;
	$fh.print($source);	
	$fh.close;
	
	my $contents = qqx/perl6 --doc=HTML $filename/;
	$contents ~~ s/^.+\<body.+?\>(.+)\<\/body\>.+$/$0/;
	
	# TODO more robust cleanup
	unlink $filename;

	return [
		200,
		[ 'Content-Type' => 'text/plain' ],
		[ $contents ],
	];
}


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

method rosettacode-search(Str something) {
	...
}

