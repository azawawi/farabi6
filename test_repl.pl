use v6;

use IO::Capture::Simple;

my $save_ctx;
my $comp = nqp::getcomp('perl6');
while 1
{
	my $code = prompt("> ");

	my ($out, $result);

	try
	{
		capture_stdout_on($out);
		$result = $comp.eval($code, :outer_ctx($save_ctx));
		capture_stdout_off;

		CATCH
		{
			default
			{
				capture_stdout_off;

				say "Error: $_";
				say $_.backtrace.Str;
			}
		}
		
	}

	say("result => " ~ $result) if defined $result;
	say("stdout => " ~ $out) if defined $out;

}

# vim: ft=perl6
