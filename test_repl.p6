
use v6;


my $save_ctx;
while 1 {
	my $code = prompt("*> ");
	try {
		say $save_ctx;
    	my $output := pir::compreg__Ps('perl6').eval($code, :outer_ctx($save_ctx));
		say $output;
		CATCH {
			default {
				say "Error: " ~ $!;
			}
		}
	}
}
