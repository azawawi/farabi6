use v6;

class Farabi6::Util {

use URI::Escape;

constant %ANSI_COLORS = %(
	# Styles
	0	=> "ansi-reset",
	1	=> "ansi-bold",
	4	=> "ansi-underline",

	# Foreground colors
	30	=> "ansi-fg-black",
	31	=> "ansi-fg-red",
	32	=> "ansi-fg-green",
	33	=> "ansi-fg-yellow",
	34	=> "ansi-fg-blue",
	35	=> "ansi-fg-magenta",
	36	=> "ansi-fg-cyan",
	37	=> "ansi-fg-white",

	# Background colors
	40	=> "ansi-bg-black",
	41	=> "ansi-bg-red",
	42	=> "ansi-bg-green",
	43	=> "ansi-bg-yellow",
	44	=> "ansi-bg-blue",
	45	=> "ansi-bg-magenta",
	46	=> "ansi-bg-cyan",
	47	=> "ansi-bg-white",
);

# Adapted from https://github.com/tadzik/Bailador/blob/master/lib/Bailador/Request.pm
method params($psgi_input)
{
	return %() unless $psgi_input;

	my %ret;
	for $psgi_input.decode.split('&') -> $p 
	{
		my $pair = $p.split('=', 2);
		%ret{$pair[0]} = uri_unescape $pair[1];
	}

	return %ret;
}
	
method get-parameter(Str $input, Str $name) {
	# TODO more generic parameter parsing
	my $value = $input;
	$value ~~ s/^$name\=//;
	uri_unescape($value);
}

=begin comment

This is a utility for sending a GET HTTP request. Right now
it is uses wget since it is the most reliable at this time
Both LWP::Simple and  suffers from installation and bugs

=end comment
method http-get(Str $url) {
    #TODO investigate whether LWP::Simple is installable and workable again
    #TODO investigate whether HTTP::Client after the promised big refactor works or not
	die "URL is not defined!" unless $url; 
	qqx/wget -qO- $url/;
}

#TODO use LWP::Simple.post if it works?
method post-request($url, $payload) {
	constant $CRLF = "\x0D\x0A";

	my $o = URI.new($url);
	my $host = $o.host;
	my $port = $o.port;
	my $req = "POST {$o.path} HTTP/1.0{$CRLF}" ~
	"Host: {$host}{$CRLF}" ~
	"Content-Length: {$payload.chars}{$CRLF}" ~ 
	"Content-Type: application/x-www-form-urlencoded{$CRLF}{$CRLF}{$payload}"; 
	
	my $client = IO::Socket::INET.new( :$host, :$port );
	$client.send( $req );
	my $response = '';
	while (my $buffer = $client.recv) {
		$response ~= $buffer;
	}
	$client.close;

	my $http_body;
	my $body = '';
	for $response.lines -> $line {
	
		if ($http_body) {
			$body ~= $line;
		} elsif ($line.chars == 1) {
			$http_body = 1;
			say "Found HTTP Body";
		}
	}

	$body;
}

#TODO refactor into Farabi::Types (like Mojo::Types)
method find-mime-type(Str $filename) {
	my %mime-types = ( 
		'html' => 'text/html',
		'css'  => 'text/css',
		'js'   => 'text/javascript',
		'png'  => 'image/png',
		'ico'  => 'image/vnd.microsoft.icon',
		'svg'  => 'image/svg+xml',
	);
	
	my $mime-type;
	if ($filename ~~ /\.(\w+)$/) {
		$mime-type = %mime-types{$0} // 'text/plain';
	} else {
		$mime-type = 'text/plain';
	}

	$mime-type;
}

=begin comment
	Finds a file inside a directory excluding list of files/directories

	Code adapted from File::Find
=end comment
method find-file($dir, $pattern) {

	my @targets = dir($dir);
	my $list = gather while @targets {
		my $elem = @targets.shift;

		my $found = 0;
		my $file-name = $elem.basename;
		my $path = $elem.Str;
		next if $path ~~ /.svn$|.git$/;

		if $elem.IO ~~ :d {
			@targets.push: dir($elem);
			CATCH {
				when X::IO::Dir { next; }
			}
		} elsif $file-name ~~ m:ignorecase/"$pattern"/ {
			take {
				'file' => $path,
				'name' => $file-name;
			};
		}
	};

	return @$list;
}

method find-ansi-color-ranges($output is rw) {
	# Create color ranges from the ANSI color sequences in the output text
	my @ranges = gather {
		my $colors;
		my $start;
		my $len    =  0;
		for $output.comb(/ \x1B '[' [ (\d+) ';'? ]+ 'm' /, :match) -> $/ {

			# Take the marked text range if possible
			take {
				"from"  => $start,
				"to"    => $/.from - $len,
				"colors" => $colors,
			} if defined $colors;

			# Decode colors into a simple CSS class name
			$colors = (map { %ANSI_COLORS{$_}  }, $/[0].list).Str;

			# Since we're going to remove ANSI colors
			# we need to shift positions to the left
			$start = $/.from - $len;
			$len   += $/.chars;
		}

		# Take the **remaining** marked text range if possible
		take {
			"from"   => $start,
			"to"     => $output.chars - $len,
			"colors" => $colors,
		} if defined $colors;

	};

	# Remove the ANSI color sequences from the output text
	$output ~~ s:g/
		\x1B
		'['
		[ [ \d+ ]? ]+ %% ';'
		'm'
	//;

	return @ranges;
}

}
