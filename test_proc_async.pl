

# Adapted from https://github.com/perl6/roast/blob/master/S17-procasync/print.t

use v6;

#my $pc = Proc::Async.new( $*EXECUTABLE, ['--'], :w );
#my $pc = Proc::Async.new( "reply", ['--'], :w );
#my $pc = Proc::Async.new( "python", :w );
my $pc = Proc::Async.new( "pry", :w );

my $so = $pc.stdout;
my $se = $pc.stderr;

my $stdout = "";
my $stderr = "";
$so.act: { say "Output:\n$_\n---"; $stdout ~= $_; };
$se.act: { say "Input:\n$_\n---"; $stderr ~= $_ };

my $pm = $pc.start;

while True {
	my $expr = prompt("!> ");
	my $ppr = $pc.print( "$expr\n" );

	#$pc.close-stdin;

	await $ppr;
}

# done processing
$pc.close-stdin;
my $ps = await $pm;

# vim:ft=perl6
