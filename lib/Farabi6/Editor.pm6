use v6;

class Farabi6::Editor {

use File::Spec;
use JSON::Tiny;
use URI::Escape;

use Farabi6::Util;

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

=begin comment

Returns the 'file-name' file searchs as a PSGI response

=end comment
method search-file(Str $file-name) {

	# Find file inside current directory exluding usual excluded stuff
	my @search-results = Farabi6::Util.find-file(
		cwd,
		$file-name, 
		['.svn', '.git']
	);

	# Return the PSGI response
	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ to-json(@search-results) ],
	];
}

=begin comment

Returns the 'file-name' file contents as a PSGI response

=end comment
method open-file(Str $file-name is copy) {

	# Assert that filename is defined 
	return [500, ['Content-Type' => 'text/plain'], ['file name is not defined!']] unless $file-name;

	# Open filename
	my ($status, $text);
	try {
		# expand ~ into $HOME
		$file-name  ~~= s/\~/{%*ENV{'HOME'}}/;
		my $fh = open $file-name, :bin;
		$text = $fh.slurp;
		$fh.close;
		$status = 200;

		CATCH {
			default {
				$status = 404;
				$text = 'Not found';
			}
		}
	}

	# Return the PSGI response
	[
		$status,
		[ 'Content-Type' => 'text/plain' ],
		[ $text ],
	];
}

=begin comment

Returns a PSGI response that contains the contents of the URL
provided

=end comment
method open-url(Str $url) {
	[
		200,
        [ 'Content-Type' => 'text/plain' ],
        [ Farabi6::Util.http-get($url) ],
	];
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

method rosettacode-rebuild-index(Str $language) {

	my $escaped-title = uri_escape("Category:{$language}");
	my $json = Farabi6::Util.post-request(
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

=begin comment

Runs code using the requested runtime and returns the output

=end comment
method run-code(Str $source, Str $runtime) {

	# TODO use File::Temp once it is usable
	my $filename = File::Spec.catfile(File::Spec.tmpdir, 'farabi-run.tmp');
	my $fh = open $filename, :w;
	$fh.print($source);
	$fh.close;	

	#TODO more portable version for win32 in the future
	my Str $cmd;
	#TODO configurable from runtime configuratooor :)
	#TODO safe command argument...
	#TODO safe runtime arguments...
	if $runtime eq 'niecza' {
		# Niecza safe mode
		$cmd = '/usr/bin/env Niecza.exe --safe';
	} else {
		# Default to Rakudo Perl 6 for now
		$cmd = '/usr/bin/env perl6';
	}
    my Str $output = qqx{$cmd $filename};

	my %result = 
		'output'   => $output;

	[
		200,
		[ 'Content-Type' => 'application/json' ],
        [ to-json(%result) ],
	];
}


}

