use v6;

class Farabi6::Editor {

use File::Temp;
use JSON::Tiny;
use URI::Escape;

use Farabi6::Util;

=begin comment

Syntax checks the current editor document for any problems using
Rakudo Perl 6

=end comment
method syntax-check(Str $source) {

	#TODO only syntax check on save like Eclipse and use real files only

	# Prepare Perl 6 source for syntax check
	my ($filename,$filehandle) = tempfile(:!unlink);
	spurt $filehandle, $source;

	# Invoke perl -c $temp_file
	my Str $output = qqx{$*EXECUTABLE -c $filename 2>&1};

	# Remove temp file
	unlink $filehandle;

	my @problems;
	unless $output ~~ /^Syntax OK/ {
		say "Checking...";
		if $output ~~ m/\n(.+?)at\s.+?\:(\d+)/ {
			push @problems, {
				'description'   => ~$/[0],
				'line_number'   => ~$/[1],
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

	# Find file inside current directory exluding .svn and .git folders
	my @search-results = Farabi6::Util.find-file(
		cwd,
		$file-name
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

	# Create a temporary file that holds the POD string
	my ($filename,$filehandle) = tempfile(:!unlink);
	spurt $filehandle, $pod;

	# Invoke perl6 -doc to convert POD to HTML
	my $html = qqx/$*EXECUTABLE --doc=HTML $filename/;

	# Remove temp file
	unlink $filehandle;

	# only <body> section is needed (HTML fragment)
	$html ~~ s/^.+\<body.+?\>(.+)\<\/body\>.+$/$0/;

	[
		200,
		[ 'Content-Type' => 'text/plain' ],
		[ $html ],
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

	# Create a temporary file that holds the POD string
	my ($filename,$filehandle) = tempfile(:!unlink);
	spurt $filehandle, $source;

	# Run code using rakudo Perl 6
	my Str $output = qqx{$*EXECUTABLE $filename 2>&1};

	# Remove temp file
	unlink $filehandle;

	my %ANSI_COLORS = {
		30	=> "fg-black",
		31	=> "fg-red",
		32	=> "fg-green",
		33	=> "fg-yellow",
		34	=> "fg-blue",
		35	=> "fg-magenta",
		36	=> "fg-cyan",
		37	=> "fg-white"
	};

#TODO more robust ANSI sequence parsing

	# Create color ranges from the ANSI color sequences in the output text
	my @ranges = gather {
		my $start = -1;
		my $color = "";
		my $len   = 0;
		while $output ~~ m:c/\x1B\[(\d+)m/ {
			if $start == -1 {
				$start = $/.from - $len;
				$len   += $/.chars;
				$color = %ANSI_COLORS{$/[0]};
			} else {
				$len   += $/.chars;
				take {
					"from"  => $start,
					"to"    => $/.to - $len,
					"color" => $color,
				};
				$start = -1;
			}
		}
	};

	# Remove the ANSI color sequences from the output text
	$output ~~ s:g/\x1B\[\d+m//;

	#TODO configurable from runtime configuratooor :)
	#TODO safe command argument...
	#TODO safe runtime arguments...

	my %result = {
		'output'   => $output,
		'ranges'   => @ranges,
	}

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ to-json(%result) ],
	];
}


}

