
use v6;

use JSON::Tiny;
use HTTP::UserAgent;
#use URI::Escape;

my $page_title = 'Create%20a%20file';
my $url = "http://rosettacode.org/mw/api.php?format=json&action=query&titles={$page_title}&prop=revisions&rvprop=content";

my $ua = HTTP::UserAgent.new;
$ua.timeout = 10;

try my $response = $ua.get($url);

if $response.is-success {
    my $t = $response.content.decode;
	"result.json".IO.spurt($t);
	my $o = from-json($t);
	say $o{"query"}{"pages"};
	say $o{"query"}{"pages"}{"2027"}{"title"};
	say $o{"query"}{"pages"}{"2027"}{"revisions"};
} else {
    die $response.status-line;
}