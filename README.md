Farabi6
=======

This is a fun Perl 6 port of the Farabi Modern Perl Editor http://metacpan.org/module/Farabi.
The idea here is to experiment with a Perl 6 in-browser editor running over Rakudo Perl 6. 

Have fun!

## Installation

To run it from the local directory:

    bin/farabi6
    # Open http://localhost:3030 in your browser

To install it using Panda (a module management tool bundled with Rakudo Star):

    panda update
    panda install Farabi6
    farabi6
    # Open http://localhost:3030 in your browser

To install it using ufo (A tool to create your Perl 6 project Makefile for you):

	ufo              # Create Makefile
	make
	make test
	make install

You can also change the host name and port using the following command:

    farabi6 --host=localhost --port=4040

## Environment Variables

	# Enable unsafe mode which includes running unsafe code on your local system
	FARABI6_UNSAFE=1 farabi6

## Testing

To run tests:

    prove -e perl6

## Author

Ahmad M. Zawawi, azawawi on #perl6, https://github.com/azawawi/

## License

Artistic License 2.0
