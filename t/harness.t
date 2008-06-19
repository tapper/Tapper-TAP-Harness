#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';

my $tap = slurp ("t/tap_archive_artemis.tap");

# ============================================================

plan tests => 21;

my $harness = new Artemis::TAP::Harness( tap => $tap );

$harness->evaluate_report();

is(scalar @{$harness->parsed_report->{tap_sections}}, 10, "count sections");

my $first_section = $harness->parsed_report->{tap_sections}->[0];

# use Data::Dumper;
# diag(Dumper($first_section));

is($harness->parsed_report->{report_meta}{'suite-name'},    'Artemis',  "report meta suite name");
is($harness->parsed_report->{report_meta}{'suite-version'}, '2.010004', "report meta suite version");
is($harness->parsed_report->{report_meta}{'suite-type'},    'software', "report meta suite type");
is($harness->parsed_report->{report_meta}{'machine-name'},  'bascha',   "report meta machine name");
is($harness->parsed_report->{report_meta}{'starttime-test-program'}, 'Fri Jun 13 11:16:35 CEST 2008',                                      "report meta starttime test program");

is($first_section->{section_name},'t/00-artemis-meta.t', "first section name");

is($first_section->{section_meta}{'suite-name'},             'Artemis',                                                            "report meta suite name");
is($first_section->{section_meta}{'suite-version'},          '2.010004',                                                           "report meta suite version");
is($first_section->{section_meta}{'suite-type'},             'software',                                                            "report meta suite type");
is($first_section->{section_meta}{'language-description'},   'Perl 5.010000, /2home/ss5/perl510/bin/perl',                         "report meta language description");
is($first_section->{section_meta}{'uname'}, 'Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux', "report meta uname");
is($first_section->{section_meta}{'osname'},                 'Ubuntu 8.04',                                                        "report meta osname");
is($first_section->{section_meta}{'cpuinfo'},                '2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]',           "report meta cpuinfo");
is($first_section->{section_meta}{'ram'},                    '1887MB',                                                             "report meta ram");

is($first_section->{db_section_meta}{'language_description'},   'Perl 5.010000, /2home/ss5/perl510/bin/perl',                                          "db meta language description");
is($first_section->{db_section_meta}{'uname'},                  'Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux', "db meta uname");
is($first_section->{db_section_meta}{'osname'},                 'Ubuntu 8.04',                                                                         "db meta osname");
is($first_section->{db_section_meta}{'cpuinfo'},                '2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]',                            "db meta cpuinfo");
is($first_section->{db_section_meta}{'ram'},                    '1887MB',                                                                              "db meta ram");

$harness = new Artemis::TAP::Harness( tap => $tap );
my $html = $harness->generate_html;
is(scalar @{$harness->parsed_report->{tap_sections}}, 10, "count sections"); # check to trigger preparation errors
