#!/usr/bin/env perl6
use v6;

use NativeCall;

constant LIB = 'libncurses.so.5';

sub initscr()        is native(LIB) { ... };
sub clear()          is native(LIB) { ... };
sub endwin()         is native(LIB) { ... };
sub printw(Str)      is native(LIB) { ... };
#sub NCURSEsrefresh() is native(LIB) { ... };
sub getch()  	     is native(LIB) { ... };

initscr;			# Start curses mode
printw("Hello World !!!\n");	# Print Hello World
printw("Wtf\n");
printw("zzz\n");
#NCURSEsrefresh;			# Print it on to the real screen
getch;			# Wait for user input
endwin;			# End curses mode
