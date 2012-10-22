use v6;

BEGIN { @*INC.push('lib') };

use Test;

plan 2;

use Farabi6;

ok 1, "use Farabi6 worked!";
ok Farabi6.new, "Farabi6.new worked";
