use v6;

# Display https://raw.githubusercontent.com/azawawi/farabi6/master/README.md
use IO::Socket::SSL;
my $ssl = IO::Socket::SSL.new(:host<raw.githubusercontent.com>, :port(443));
my $content;
$ssl.send("GET /azawawi/farabi6/master/README.md HTTP/1.1\r\nHost: raw.githubusercontent.com\r\n\r\n");
while my $read = $ssl.recv {
	$content ~= $read;
}
say $content;
