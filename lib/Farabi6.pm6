use v6;

# External
use File::Spec;
use HTTP::Easy::PSGI;
use URI::Escape;

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

	my $http = HTTP::Easy::PSGI.new(:$host, :$port);
	my $app = sub (%env)
	{
		my Str $filename;
   		my Str $uri = %env<REQUEST_URI>;
		$uri ~~= s/\?.*$//;
		if ($uri eq '/') {
			$filename = 'index.html';
		} elsif ($uri eq '/pod2html') { 
			return self.pod2html(%env<psgi.input>);
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

		if (!@contents) {
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

method pod2html(Buf $input) {

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

