#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';
use Data::Dumper;

plan tests => 4;

my $tap;
my $harness;
my $interrupts_before_section;

# ============================================================

$tap = slurp ("t/tap_archive_kernbench_no_v13.tap");
$harness = new Artemis::TAP::Harness( tap => $tap );
$harness->evaluate_report();
print STDERR Dumper($harness->parsed_report->{tap_sections});
is( scalar @{$harness->parsed_report->{tap_sections}}, 15, "kernbench_no_v13 section name interrupts-before count");
$interrupts_before_section = $harness->parsed_report->{tap_sections}->[1];
is ($interrupts_before_section->{section_name}, 'stats-proc-interrupts-before', "kernbench_no_v13 section name interrupts-before");

# ============================================================

$tap     = slurp ("t/tap_archive_kernbench2.tap");
$harness = new Artemis::TAP::Harness( tap => $tap );
$harness->evaluate_report();
#print STDERR Dumper($harness->parsed_report->{tap_sections});
is( scalar @{$harness->parsed_report->{tap_sections}}, 15, "kernbench2 section name interrupts-before count");
$interrupts_before_section = $harness->parsed_report->{tap_sections}->[1];
is ($interrupts_before_section->{section_name}, 'stats-proc-interrupts-before', "kernbench2 section name interrupts-before");

