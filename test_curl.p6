#!/usr/bin/env perl6
use v6;

use NativeCall;

constant LIB = 'libcurl.so';

sub curl_version() returns Str is native(LIB) { ... };

say "Your libcurl version is " ~ curl_version;
