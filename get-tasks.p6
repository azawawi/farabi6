#!/usr/bin/env perl6
use v6;

=begin pod

This script connects to Rosetta Code Project and lists
all the tasks in Rosetta Code Project for Perl 6

=end pod

#use LWP::Simple;
#my $content = LWP::Simple.get('http://rosettacode.org/');
#if (my $fh = open 'rosettacode.html', :w) {
#	$fh.say($content);
#	$fh.close;
#}

use HTTP::Client;
my $client = HTTP::Client.new;
my $response = $client.get('http://rosettacode.org/');
say $response.content if $response.success;
