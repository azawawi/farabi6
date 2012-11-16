#!/usr/bin/env perl6
use v6;

use NativeCall;

constant LIB = 'libcurl.so';

sub curl_easy_init() returns OpaquePointer is native(LIB) { ... };
sub curl_easy_cleanup(OpaquePointer)      is native(LIB) { ... };
sub curl_easy_setopt(OpaquePointer, int, Str) is native(LIB) { ... };
sub curl_easy_perform(OpaquePointer) returns int is native(LIB) { ... };
sub curl_easy_strerror(int) returns Str is native(LIB) { ... };

constant CURLOPT_URL = 10002;
constant CURLE_OK    = 0;

my $curl;
my $res;
 
$curl = curl_easy_init;
if $curl {
    curl_easy_setopt($curl, CURLOPT_URL, "http://example.com");
 
    # Perform the request, res will get the return code
    $res = curl_easy_perform($curl);

    # Check for errors
    if $res != CURLE_OK {
      say "Error: curl_easy_perform() failed: {curl_easy_strerror($res)}\n";
 	} else {
		say "Got a response!";
	}
	say "libcurl initialized!";

    # always cleanup 
    curl_easy_cleanup($curl);
}
