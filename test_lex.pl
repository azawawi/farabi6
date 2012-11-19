#!/usr/bin/env perl

use Modern::Perl;

my $target;
if(@ARGV) {
	$target = join(' ', @ARGV);
} else {
	$target = q{say "Hello world";};
}

use Data::Printer;

my @tokens;
while (1) {
    if ( $target =~ /\G(([\$\@\%])?[A-Za-z_]([A-Za-z_0-9]|(\-[A-Za-z_0-9]))+)/gc ) {
        push @tokens, [ 'IDENTIFIER', $1, pos($target) - length($1) ];
    }
    elsif ( $target =~ /\G(\".+\")/gc ) {
        push @tokens, [ 'DOUBLE_QUOTE', $1, pos($target) - length($1) ];
    }
    elsif ( $target =~ /\G([\-\+\*\/])/gc ) {
        push @tokens, [ 'OPERATOR', $1, pos($target) - length($1) ];
    }
    elsif ( $target =~ /\G(\d+)/gc ) {
        push @tokens, [ 'INTEGER', $1, pos($target) - length($1) ];
    }
    elsif ( $target =~ /\G(\s+)/gc ) {
        push @tokens, [ 'WHITESPACE', $1, pos($target) - length($1) ];
    }
    elsif ( $target =~ /\G(;)/gc ) {
        push @tokens, [ 'SYMBOL', $1, pos($target) - length($1) ];
    }
    else {
        last;
    }
}

p($target);
p(@tokens)
