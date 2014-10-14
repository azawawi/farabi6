use v6;

class Farabi6::Editor {

use File::Temp;
use JSON::Tiny;
use URI::Escape;

use Farabi6::Util;


# Profile HTML files to unlink (i.e. delete)
my Str @profiles_to_unlink;

# Cache Panda projects.json (Array of hashes)
my $modules;

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
		$text = $file-name.IO.slurp;
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

Runs code using a Perl 6 runtime and returns the output

=end comment
method run-code(Str $source, $args = '') {

	#TODO check source and runtime-args parameters

	# Create a temporary file that holds the POD string
	my ($filename,$filehandle) = tempfile(:!unlink);
	spurt $filehandle, $source;

	# Run code using rakudo Perl 6
	my $t0 = now;

	my Str $output = qqx{$*EXECUTABLE $args $filename 2>&1};
	my $duration = sprintf("%.3f", now - $t0);

	# Remove temp file
	unlink $filehandle;

	my %ANSI_COLORS = %(
		# Styles
		0	=> "ansi-reset",
		1	=> "ansi-bold",
		4	=> "ansi-underline",

		# Foreground colors
		30	=> "ansi-fg-black",
		31	=> "ansi-fg-red",
		32	=> "ansi-fg-green",
		33	=> "ansi-fg-yellow",
		34	=> "ansi-fg-blue",
		35	=> "ansi-fg-magenta",
		36	=> "ansi-fg-cyan",
		37	=> "ansi-fg-white",

		# Background colors
		40	=> "ansi-bg-black",
		41	=> "ansi-bg-red",
		42	=> "ansi-bg-green",
		43	=> "ansi-bg-yellow",
		44	=> "ansi-bg-blue",
		45	=> "ansi-bg-magenta",
		46	=> "ansi-bg-cyan",
		47	=> "ansi-bg-white",
	);

	# Create color ranges from the ANSI color sequences in the output text
	my @ranges = gather {
		my $colors;
		my $start;
		my $len    =  0;
		while $output ~~ m:c/ \x1B \[ [(\d+)\;?]+ m / {

			# Take the marked text range if possible
			take {
				"from"  => $start,
				"to"    => $/.from - $len,
				"colors" => $colors,
			} if defined $colors;

			# Decode colors into a simple CSS class name
			$colors = (map { %ANSI_COLORS{$_}  }, $/[0].list).Str;

			# Since we're going to remove ANSI colors
			# we need to shift positions to the left
			$start = $/.from - $len;
			$len   += $/.chars;
		}

		# Take the **remaining** marked text range if possible
		take {
			"from"   => $start,
			"to"     => $output.chars - $len,
			"colors" => $colors,
		} if defined $colors;

	};

	# Remove the ANSI color sequences from the output text
	$output ~~ s:g/ \x1B \[ [(\d+)\;?]+ m //;

	#TODO configurable from runtime configuratooor :)
	#TODO safe command argument...
	#TODO safe runtime arguments...

	my $profile-id = '';
	if    $args eq '--profile' 
	   && $output ~~ /Wrote\sprofiler\soutput\sto\s(profile\-(.+?)\.html)/
	{
		my Str $profile-file = $/[0].Str;
		$profile-id = $/[0][0].Str;

		# Schedule file for cleanup at END
		say "Found $profile-file. Scheduling for cleanup at END";
		@profiles_to_unlink.push($profile-file);
	}

	my %result = %(
		'output'     => $output,
		'ranges'     => @ranges,
		'duration'   => $duration,
		'profile_id' => $profile-id,
	);

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ to-json(%result) ],
	];
}

# DEAD CODE for later investigation
#my $pc;
#my $stdout = "";
#my $stderr = "";

=begin comment

Runs expression using Perl 6 REPL and returns the output

=end comment
method eval-repl-expr(Str $expr) {

	#TODO investigate why perl6 does not invoke its REPL when invoked from an outside process
	# See dead code below the method please

	# do a simple eval for now
	my $t0 = now;
	my $output = EVAL $expr;
	my $duration = sprintf("%.3f", now - $t0);

	my %result = %(
		'output'   => $output,
		'duration' => $duration,
	);

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ to-json(%result) ],
	];
}

# DEAD CODE for later investigation
#	my $t0 = now;
#
#	unless defined $pc {
#		$pc = Proc::Async.new( $*EXECUTABLE, :w );
#
#		my $so = $pc.stdout;
#		my $se = $pc.stderr;
#
#		$so.act: { say "Output:\n$_\n---"; $stdout ~= $_; };
#		$se.act: { say "Input:\n$_\n---"; $stderr ~= $_ };
#
#		my $pm = $pc.start;
#	}
#
#	my $ppr = $pc.print( "$expr\n" );
#	await $ppr;
#
#	my $duration = sprintf("%.3f", now - $t0);
#
#	my Str $output = $stdout ~ $stderr;
#
#	# done processing
#	#$pc.close-stdin;
#	#my $ps = await $pm;

=begin comment

Returns the profile HTML file that is generated with
the perl6 --profile command to be downloaded by the user

=end comment
method profile-results(Str $id) {

	my $file-name = "profile-{$id}.html";
	if defined($id) && $file-name.IO ~~ :f
	{
		say "Serving $file-name to user";
		# Found a valid profile HTML file with a valid id
		return
			[
				200,
				[ 'Content-Type' => 'text/html' ],
				[ $file-name.IO.slurp ],
			] ;
	} else {
		# Not found or invalid id
		return
			[
				404,
				[ 'Content-Type' => 'text/plain' ],
				[ "Not found" ],
			];
	}
}

=begin comment

Run panda search pattern and return the results as JSON

=end comment
method module-search(Str $pattern is copy) {

	# Trim the pattern and make sure we dont fail on undefined
	$pattern = $pattern // '';
	$pattern = $pattern.trim;

	# Start stopwatch
	my $t0 = now;

	unless defined $modules
	{
		# Since we do not have any cached modules,
		# we need to build one
		say "Building module list (once)";

		# Find panda/projects.json
		my @dirs = $*SPEC.splitdir($*EXECUTABLE);
		my $projects-json = $*SPEC.catdir(
			@dirs[0..*-3],
			'languages', 'perl6', 'site', 'panda', 'projects.json'
		);

		if $projects-json.IO ~~ :f
		{
			say "Found project metadata: {$projects-json}";
			$modules = from-json($projects-json.IO.slurp);
			say "Parsed {$modules.elems} modules(s) from $projects-json";
		}
	}

	# filter modules by name using given pattern
	constant $MAX_SIZE = 20;
	my $count = 0;
	my @results = gather for @$modules -> $module
	{
		my $name = $module{"name"}        // '';
		my $desc = $module{"description"} // '';
		my $url  = $module{"source-url"}  // '#';

		$url = $url.subst(/^git/, 'https');
		$url = $url.subst(/\.git$/, '');

		if    $pattern eq ''
		   || $name    ~~ m:i/$pattern/
		   || $desc    ~~ m:i/$pattern/
		{
			take {
				"name" => $name,
				"desc" => $desc,
				"url"  => $url,
			};

			$count++;
			if $count >= $MAX_SIZE {
				last;
			}
		}
	}

	say "Matched {@results.elems} module(s)";

	# Stop stopwatch and calculate the duration
	my $duration = sprintf("%.3f", now - $t0);

	# PSGI response
	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'results'  => @results.sort,
					'duration' => $duration,
				)
			)
		],
	];
}

# Cleanup on server exit
END {
	say "Cleaning up profile HTMLs";
	for @profiles_to_unlink -> $profile {
		say "Deleting $profile";
		unlink $profile;
	}
}

}
