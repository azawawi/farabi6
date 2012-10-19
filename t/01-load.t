use v6;

BEGIN { @*INC.push('lib') };

use Farabi6;
use Test;

plan 1;

my $editor = Farabi6.new;
ok $editor, "Farabi6.new worked";
