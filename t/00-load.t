#!perl -T

use Test::More;

plan tests => 1;

BEGIN {
	use_ok( 'Artemis::TAP::Harness' );
}

diag( "Testing Artemis::TAP::Harness $Artemis::TAP::Harness::VERSION, Perl $], $^X" );
