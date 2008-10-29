#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';

my $tap = slurp ("t/tap_archive_much_whitespace.tap");

# ============================================================

plan tests => 8;

my $harness = new Artemis::TAP::Harness( tap => $tap );

$harness->evaluate_report();

is(scalar @{$harness->parsed_report->{tap_sections}}, 11, "count sections");

my $first_section = $harness->parsed_report->{tap_sections}->[0];

is($harness->parsed_report->{report_meta}{'suite-name'},    'Artemis-CTCS',             "report meta suite name");
is($harness->parsed_report->{report_meta}{'suite-version'}, '0.2',                      "report meta suite version");
is($harness->parsed_report->{report_meta}{'machine-name'},  'rhel5u2.64bit',            "report meta machine name");
is($harness->parsed_report->{report_meta}{'starttime-test-program'}, '20081028T135316', "report meta starttime test program");

is($first_section->{section_name},'artemis-meta-information', "first section name");

is($first_section->{section_meta}{'suite-name'},             'Artemis-CTCS',                                                            "report meta suite name");
is($first_section->{section_meta}{'suite-version'},          '0.2',                                                           "report meta suite version");

