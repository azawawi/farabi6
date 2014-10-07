#!/usr/bin/env perl6

use v6;


#my $html = slurp 'test_1.html';

#=begin i
my $html = q:to/END/;
<pre class="perl6 highlighted_source">
1
1.1
</pre>
<pre>2</pre>
<pre>3</pre>
<pre>4</pre>
END
#=end i

#<pre class="perl6 highlighted_source">


#
while $html ~~ m:c/\<pre\sclass\=\"perl6\shighlighted_source\"\>(.+?)\<\/pre\>/ {
	say $/[0].Str;
}

#else {
#	say "No match";
#}

#my $x = '<pre class="perl6 highlighted_source">';


