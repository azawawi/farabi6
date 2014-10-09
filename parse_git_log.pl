use v6;

my $git_dir = '/home/azawawi/farabi6/.git';
my $output = qqx{git --git-dir=$git_dir log --numstat};

say $output;

for $output.lines -> $line {

	my %commit;
	if $line ~~ /^commit\s+(<[a..f 0..9]>+)$/ {
		%commit{"commit"} = $/[0];
	} elsif $line ~~ /^Author\:\s+(.+)$/ {
		%commit{"author"} = $/[0];
	} elsif $line ~~ /^Date\:\s+(.+)$/ {
		%commit{"date"} = $/[0];
	}# elsif $line 
	
	#say %commit;
}

#TODO parse

# Profit :)