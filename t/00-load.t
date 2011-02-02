#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Tapper::TAP::Harness' );
}

diag( "Testing Tapper::TAP::Harness $Tapper::TAP::Harness::VERSION, Perl $], $^X" );
