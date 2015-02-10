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

# Cache p6doc index.data (Hash of help topics strings)
my %help_index;

=begin comment

Syntax checks the current editor document for any problems using
Rakudo Perl 6

=end comment
method syntax-check(Str $source) {

	#TODO only syntax check on save like Eclipse and use real files only

	# Prepare Perl 6 source for syntax check
	my ($filename,$filehandle) = tempfile(:!unlink);
	$filehandle.print($source);

	# Invoke perl -c $temp_file
	my Str $output = qqx{$*EXECUTABLE -c $filename 2>&1};

	# ANSI colors
	my @ranges = Farabi6::Util.find-ansi-color-ranges($output);

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

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'problems' => @problems,
					'ranges'   => @ranges,
					'output'   => $output
				)
			)
		],
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
		$file-name .= subst('~', %*ENV<HOME>);
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
	$filehandle.print($source);

	# Run code using rakudo Perl 6
	my $t0 = now;

	my Str $output = qqx{$*EXECUTABLE $args $filename 2>&1};
	my $duration = sprintf("%.3f", now - $t0);

	# Remove temp file
	unlink $filehandle;

	# ANSI colors
	my @ranges = Farabi6::Util.find-ansi-color-ranges($output);

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


=begin comment

Runs expression using Perl 6 REPL and returns the output

=end comment
method eval-repl-expr(Str $expr) {

	#TODO investigate why perl6 does not invoke its REPL when invoked from an outside process
	# See dead code below the method please

	# do a simple eval for now
	my $t0 = now;
	my $output;
	try {
		$output = EVAL $expr;

		CATCH {
			my $duration = sprintf("%.3f", now - $t0);
			return [
				200,
				[ 'Content-Type' => 'application/json' ],
				[
					to-json(
						%(
							'output'    => ~$_,
							'duration'  => $duration,
						)
					)
				]
			];
		}
	}
	my $duration = sprintf("%.3f", now - $t0);

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'output'   => $output,
					'duration' => $duration,
				)
			) 
		],
	];
}

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

Return module search matched results against the given pattern
in JSON format

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
		   || $name    ~~ m:i/"$pattern"/
		   || $desc    ~~ m:i/"$pattern"/
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
					'results'  => @results.sort(-> $a, $b { uc($a) leg uc($b) }),
					'duration' => $duration,
				)
			)
		],
	];
}

=begin comment

Run command and process ANSI colors if any if found

=end comment
method run-command(Str $command)
{
	#TODO validate $command

	# Start stopwatch
	my $t0 = now;

	my Str $output = qqx{$command};

	# ANSI colors
	my @ranges = Farabi6::Util.find-ansi-color-ranges($output);

	# Stop stopwatch and calculate the duration
	my $duration = sprintf("%.3f", now - $t0);

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'output'   => $output,
					'ranges'   => @ranges,
					'duration' => $duration,
				)
			)
		],
	];
}

=begin comment

Return help search matched results against the given pattern
in JSON format

=end comment
method help-search(Str $pattern is copy) {

	# Trim the pattern and make sure we dont fail on undefined
	$pattern = $pattern // '';
	$pattern = $pattern.trim;

	# Start stopwatch
	my $t0 = now;

	unless %help_index {
		my $index-file = qx{p6doc-index path-to-index}.chomp;
		unless $index-file.path ~~ :f
		{
			say "Building index.data... Please wait";

			# run p6doc-index build to build the index.data file
			my Str $dummy = qqx{p6doc-index build};
		}

		if $index-file.path ~~ :f
		{
			say "Loading index.data... Please wait";
			%help_index = EVAL $index-file.IO.slurp;
		}
		else
		{
			say "Cannot find $index-file";
		}
	}

	constant $MAX_SIZE = 20;
	my $count = 0;
	my @results = gather for %help_index.keys -> $topic
	{
		if $topic ~~ m:i/"$pattern"/ {
			take {
				"name" => $topic,
				"desc" => %help_index{$topic}[0].words[0],
				"url"  => "#",
			};

			$count++;
			if $count >= $MAX_SIZE {
				last;
			}
		}
	}

	# Stop stopwatch and calculate the duration
	my $duration = sprintf("%.3f", now - $t0);

	# PSGI response
	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'results'  => @results.sort(-> $a, $b { uc($a) leg uc($b) }),
					'duration' => $duration,
				)
			)
		],
	];
}

my %debug_sessions;
my $debug_session_id = 0;

=begin comment

Start a debugging session with the given source code string

=end comment
method start-debugging-session(Str $source)
{
	my @dirs = $*SPEC.splitdir($*EXECUTABLE);
	my $perl6-debug = $*SPEC.catdir(
		@dirs[0..*-2],
		'perl6-debug-m'
	);

	# Prepare Perl 6 source for syntax check
	my ($filename,$filehandle) = tempfile(:!unlink);
	spurt $filehandle, $source;

	# Prepare command line
	my Str $cmd = qq{$perl6-debug $filename 2>&1};

	#TODO Remove temp file on END?
	##unlink $filehandle;

	# Start debugging the temporary script
	my $pc = Proc::Async.new( "perl6-debug-m", [$filename], :w );

	my Str $result_session_id = ~$debug_session_id;
	$debug_session_id++;
	
	# Record debug session
	%debug_sessions{$result_session_id} = %(
		pc      => $pc,
		pm      => 0,
		results => [],
		stdout  => '',
		stderr  => '',
	);

	my $so = $pc.stdout;
	my $se = $pc.stderr;

	$so.act: {
		my $response = $_;

		my $ESC               = "\x1B";
		my $ANSI_BLUE        = / $ESC '[34m' /;
		my $ANSI_RESET       = / $ESC '[0m' /;
		my $ANSI_BOLD_YELLOW = / $ESC '[1;33m' /;
		my $ANSI_MAGENTA     = / $ESC '[35m' /;

		my ($file, $from, $to);

		my $session = %debug_sessions{$result_session_id};

		if $response ~~ /^ $ANSI_MAGENTA '>>>' \s+ 'LOADING' (.+?) $ /
		{
			"Loading $0".say;
		} elsif $response ~~ /^ $ANSI_BLUE
			'+' \s+
			(.+?)    #file name
			\s+
			'(' 
				(\d+) 	# from line
				\s+ 
				'-' 
				\s+ 
				(\d+) 	# to line
			')'
			$ANSI_RESET \n (.+?) $ /
		{
			my ($file, $from, $to, $code) = ~$0, ~$1, ~$2, ~$3;

			my $line_count = $from;
			my @results = gather
			{
				for $code.split(/$ANSI_BLUE '|' \s+ $ANSI_RESET/) -> $line
				{

					if $line ~~ / $ANSI_BOLD_YELLOW .+? $ANSI_RESET /
					{
						take {
							line     => $line_count-2,  # Subtract one line for the empty space from the split
														# Subtract one line to make it zero-based
							start    => $/.from,
							end      => $/.to - 11,
						};
					}
					$line_count++;
				}
			};

			%$session<results> = @results;
		}
		elsif $response ~~ / ^ $ANSI_BLUE '>' \s+ $ANSI_RESET $ /
		{
			say "Found debug prompt...";
		} else
		{
			%$session<stdout> ~= $_;
		}

		$_;
	}

	$se.act: {
		my $session = %debug_sessions{$result_session_id};
		%$session<stderr> ~= $_;
	}

	my $session = %debug_sessions{$result_session_id};
	%$session<pm> =  $pc.start;

	return $result_session_id,
}


=begin comment

Step in

=end comment
method debug-step-in(Str $debug-session-id is copy, Str $source)
{
	my $session = %debug_sessions{$debug-session-id};
	
	if $session.defined
	{
		# Valid session, let us print to it
		if $session<pm>.status == Planned
		{
			my $pc = %$session<pc>;
			my $ppr = $pc.print("\n");
			await $ppr;
		} else
		{
			# Remove the invalid session
			$session:delete;

			# Reset debug session
			$debug-session-id = '-1';

			# Add a user friendly message to signify the demise of a promise :)
			%$session<stdout> ~= "\nDebugging Finished";
		}
	}
	else
	{
		$debug-session-id = self.start-debugging-session($source);
		$session = %debug_sessions{$debug-session-id};
	}
	
	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'id'         => $debug-session-id,
					'results'    => %$session<results>,
				)
			)
		],
	];
}

=begin comment

Step in

=end comment
method debug-status(Str $debug-session-id)
{

	my $session = %debug_sessions{$debug-session-id};
	my ($stdout, $stderr, $ranges) = ('', '', []);
	if $session.defined {
		$stdout = %$session<stdout>;
		$stderr = %$session<stderr>;
		$ranges = %$session<results>;
	}

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'id'      => $debug-session-id,
					'stdout'  => $stdout,
					'stderr'  => $stderr,
					'ranges'  => $ranges;
				)
			)
		],
	];
}

=begin comment

Step out

=end comment
method debug-step-out(Str $debug-session-id is copy, Str $source)
{

	my $session = %debug_sessions{$debug-session-id};
	
	if $session.defined
	{
		# Valid session, let us print to it
		if $session<pm>.status == Planned
		{
			my $pc = %$session<pc>;
			my $ppr = $pc.print("so\n");
			await $ppr;
		} else
		{
			# Remove the invalid session
			$session:delete;

			# Reset debug session
			$debug-session-id = '-1';

			# Add a user friendly message to signify the demise of a promise :)
			%$session<stdout> ~= "\nDebugging Finished";
		}
	}
	else
	{
		$debug-session-id = self.start-debugging-session($source);
		$session = %debug_sessions{$debug-session-id};
	}
	
	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'id'         => $debug-session-id,
					'results'    => %$session<results>,
				)
			)
		],
	];
}

=begin comment

Debug Resume...

=end comment
method debug-resume(Str $debug-session-id is copy, Str $source)
{

	my $session = %debug_sessions{$debug-session-id};
	
	if $session.defined
	{
		# Valid session, let us print to it
		if $session<pm>.status == Planned
		{
			my $pc = %$session<pc>;
			my $ppr = $pc.print("rt\n");  # Run until the next breakpoint or an exception is thrown
			await $ppr;
		} else
		{
			# Remove the invalid session
			$session:delete;

			# Reset debug session
			$debug-session-id = '-1';

			# Add a user friendly message to signify the demise of a promise :)
			%$session<stdout> ~= "\nDebugging Finished";
		}
	}
	else
	{
		$debug-session-id = self.start-debugging-session($source);
		$session = %debug_sessions{$debug-session-id};
	}
	
	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[
			to-json(
				%(
					'id'         => $debug-session-id,
					'results'    => %$session<results>,
				)
			)
		],
	];
}

=begin comment

Stop debug mode

=end comment
method debug-stop(Str $debug-session-id is copy)
{

	my $session = %debug_sessions{$debug-session-id};

	if $session.defined
	{
		# Remove the session
		$session:delete;
	}

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ '' ]
	];
}

=begin comment

Runs 'prove -e perl6' and returns the output

=end comment
method run-tests {

	# Run code using rakudo Perl 6
	my $t0 = now;

	my Str $output = qqx{prove -e perl6 2>&1};
	my $duration = sprintf("%.3f", now - $t0);

	# ANSI colors
	my @ranges = Farabi6::Util.find-ansi-color-ranges($output);

	my %result = %(
		'output'     => $output,
		'ranges'     => @ranges,
		'duration'   => $duration,
	);

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ to-json(%result) ],
	];
}

=begin doc

Trim the trailing whitespace of the provided source code

=end doc
method trim-trailing-whitespace(Str $source)
{
	# Trim trailing whitespace
	my Str $output = $source.lines.map({ $_.subst(/\s+$/,"") }).join("\n");

	my %result = %(
		'output'     => $output,
		'changed'    => $output ne $source,
	);

	[
		200,
		[ 'Content-Type' => 'application/json' ],
		[ to-json(%result) ],
	];
}

# Cleanup on server exit
END {
	# Any profile html files to delete?
	if @profiles_to_unlink
	{
		# Delete them
		say "Cleaning up profile HTMLs...";
		for @profiles_to_unlink -> $profile {
			unlink $profile;
		}
	}
}

}
