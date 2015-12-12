use v6;

use lib 'lib';

use Test;

plan 6;

use Farabi6;
ok 1, "'use Farabi6' worked!";
ok Farabi6.new, "Farabi6.new worked";

use Farabi6::Editor;
ok 1, "'use Farabi6::Editor worked!";
ok Farabi6::Editor.new, "Farabi6.Editor.new worked";

use Farabi6::Util;
ok 1, "'use Farabi6::Util worked!";
ok Farabi6::Util.new, "Farabi6::Util.new worked";
