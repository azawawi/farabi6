

# Adapted from https://github.com/perl6/roast/blob/master/S17-procasync/print.t

use v6;

my $pc = Proc::Async.new( "perl6-debug-m", ['test.pl'], :w );

my $so = $pc.stdout;
my $se = $pc.stderr;

my $stdout = "";
my $stderr = "";
$so.act: {
	my $response = $_;
	
	my $ANSI_BLUE        = / \x1B '[34m' /;
	my $ANSI_RESET       = / \x1B '[0m' /;
	my $ANSI_BOLD_YELLOW = / \x1B '[1;33m' /;

	my ($file, $from, $to);
	
	if $response ~~ /^ $ANSI_BLUE 
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
		$ANSI_RESET (.+?) $ /
	{
		my ($file, $from, $to, $code) = ~$0, ~$1, ~$2, ~$3;
		say "\nfile: $file, from: $from, to: $to";
		
		my ($row, $col_start, $col_end);
		my $line_count = $from;
		my @results = gather {
			for $code.split(/$ANSI_BLUE '|' \s+ $ANSI_RESET/) -> $line
			{
				
				if $line ~~ / $ANSI_BOLD_YELLOW .+? $ANSI_RESET /
				{
					take {
						line     => $line_count,
						start    => $/.from,
						end      => $/.to - 11,
					};
				} 
				$line_count++;
			}
		};

		say "result: $_" for @results;
	}
	
	#say "Output:\n$_\n---"; $stdout ~= $_; 
}
$se.act: {
	say "Input:\n$_\n---"; $stderr ~= $_ 
}

my $pm = $pc.start;

while True {
	my $command = prompt(">>> ");
	say "You have entered $command";
	my $ppr = $pc.print($command ~ "\n");
	await $ppr;
}

say "Finished waiting";

# done processing

$pc.close-stdin;
my $ps = await $pm;

# vim:ft=perl6
