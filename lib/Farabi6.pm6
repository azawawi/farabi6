use v6;

# External
use File::Spec;
use HTTP::Easy::PSGI;
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
	unless (File::Spec.catdir($files-dir, 'farabi.js').IO ~ :e) {
		# Workaround for panda not installing non-perl files in ~/.perl6
		$files-dir = File::Spec.catdir(%*ENV{'HOME'}, '.panda', 'src', 'Farabi6', 'lib', 'Farabi6', 'files');	
		say "Panda installation found. Switching to {$files-dir}";
	}
	say "Farabi6 is going to serve files *insecurely* from {$files-dir} :)";

	say "Farabi6 listens carefully at http://$host:$port";
	my $http = HTTP::Easy::PSGI.new(:$host, :$port);
	my $app = sub (%env)
	{
		my Str $filename;
   		my Str $uri = %env<REQUEST_URI>;
		$uri ~~= s/\?.*$//;
		if ($uri eq '/') {
			$filename = 'index.html';
		} elsif ($uri eq '/pod_to_html') { 
			return self.pod-to-html(%env<psgi.input>);
		} elsif ($uri eq '/open_url') {
			return self.open-url(%env<psgi.input>);
		} else {
			$filename = $uri.substr(1);
		}

		$filename = File::Spec.catdir($files-dir, $filename);
		my Str $mime-type = self.find-mime-type($filename);
	
		my Int $status;
		my @contents;
		if ($filename.IO ~~ :e) {
			if (my $fh = open $filename, :bin ) {
				$status = 200;
				@contents = $fh.slurp;
				$fh.close;
			}
		} 
		unless (@contents) {
			$status = 404;
			$mime-type = 'text/plain';
			@contents = "Not found $uri";	
		}
		return [ 
			$status, 
			[ 'Content-Type' => $mime-type ], 
			[ @contents ] 
		];
	}
 	$http.handle($app);

}

method get-request(Str $url) {
        constant $CRLF = "\x0D\x0A";

        my $o = URI.new($url);
        my $host = $o.host;
        my $port = $o.port;
        my $req = "GET {$o.path} HTTP/1.1{$CRLF}";

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

method open-url(Buf $input) {
	# TODO more generic parameter parsing
	my $url =  $input.decode;
    $url ~~ s/^url\=//;
    $url = uri_unescape($url);

	say "URL: $url";
	my $contents = self.get-request($url);

	return [
      	 200,
         [ 'Content-Type' => 'text/plain' ],
         [ $contents ],
    ];
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

