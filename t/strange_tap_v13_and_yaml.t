#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';
use Data::Dumper;

plan tests => 2;

# ============================================================

my $tap = slurp ("t/tap_archive_kernbench2.tap");
my $harness = new Artemis::TAP::Harness( tap => $tap );
$harness->evaluate_report();
print STDERR Dumper($harness->parsed_report->{tap_sections});
is( scalar @{$harness->parsed_report->{tap_sections}}, 2, "kernbench2 section name interrupts-before count");
my $interrupts_before_section = $harness->parsed_report->{tap_sections}->[1];
is ($interrupts_before_section->{section_name}, 'stats-proc-interrupts-before', "kernbench2 section name interrupts-before");
