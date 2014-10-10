

# Adapted from https://github.com/perl6/roast/blob/master/S17-procasync/print.t

use v6;

my $program = 'async-print-tester';
my $source = '
say "Started";
while my $line = $*IN.get {
    $line.substr(0,1) eq "2"
      ?? note $line.substr(1)
      !! say $line
};
say "Done";
';
#$program.IO.spurt($source);

#my $pc = Proc::Async.new( $*EXECUTABLE, $program, :w );
my $pc = Proc::Async.new( $*EXECUTABLE, :w );

my $so = $pc.stdout;
my $se = $pc.stderr;

my $stdout = "";;
my $stderr = "";;
$so.act: { say "Output:\n$_\n---"; $stdout ~= $_; };
$se.act: { say "Input:\n$_\n---"; $stderr ~= $_ };

my $pm = $pc.start;

my $ppr = $pc.print( "1+1\n" );
await $ppr;
my $psa = $pc.say( "1 1\n" );
await $psa;

# done processing
$pc.close-stdin;
my $ps = await $pm;

END {
    unlink $program;
}

# vim:ft=perl6
