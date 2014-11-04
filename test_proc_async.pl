

# Adapted from https://github.com/perl6/roast/blob/master/S17-procasync/print.t

use v6;

my $pc = Proc::Async.new( "perl6-debug-m", ['test.pl'], :w );

my $so = $pc.stdout;
my $se = $pc.stderr;

my $stdout = "";
my $stderr = "";
$so.act: {
	my $response = $_;
	if $response ~~ /'+' \s+ (.+?) \s+ '(' (\d+) \s+ '-' \s+ (\d+) ')'/ {
		my ($file, $from, $to) = ~$0, ~$1, ~$2;
		say $file;

		# Create color ranges from the ANSI color sequences in the output text
		my @ranges = gather {
			my $colors;
			my $start;
			my $len    =  0;
			for $response.comb(/ \x1B '[' [ (\d+) ';'? ]+ 'm' /, :match) -> $/ {

				# Take the marked text range if possible
				take {
					"from"  => $start,
					"to"    => $/.from - $len,
					"colors" => $colors,
				} if defined $colors;

				# Decode colors into a simple CSS class name
				$colors = $/[0].list.Str;

				# Since we're going to remove ANSI colors
				# we need to shift positions to the left
				$start = $/.from - $len;
				$len   += $/.chars;
			}

			# Take the **remaining** marked text range if possible
			take {
				"from"   => $start,
				"to"     => $response.chars - $len,
				"colors" => $colors,
			} if defined $colors;

		};
		
		say $_ for @ranges;

	}
	say "Output:\n$_\n---"; $stdout ~= $_; 
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
