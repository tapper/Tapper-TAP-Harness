#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';

my $tap = slurp ("t/tap_archive_artemis.tap");

# ============================================================

plan tests => 20;

my $harness = new Artemis::TAP::Harness( tap => $tap );

$harness->evaluate_report();

is(scalar @{$harness->parsed_report->{tap_sections}}, 10, "count sections");

is($harness->parsed_report->{report_meta}->{'suite-name'},             'Artemis',                                                            "report meta suite name");
is($harness->parsed_report->{report_meta}->{'suite-version'},          '2.010004',                                                           "report meta suite version");
is($harness->parsed_report->{report_meta}->{'suite-type'},             'library',                                                            "report meta suite type");
is($harness->parsed_report->{report_meta}->{'language-description'},   'Perl 5.010000, /2home/ss5/perl510/bin/perl',                         "report meta language description");
is($harness->parsed_report->{report_meta}->{'machine-name'},           'bascha',                                                             "report meta machine name");
is($harness->parsed_report->{report_meta}->{'uname'}, 'Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux', "report meta uname");
is($harness->parsed_report->{report_meta}->{'osname'},                 'Ubuntu 8.04',                                                        "report meta osname");
is($harness->parsed_report->{report_meta}->{'cpuinfo'},                '2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]',           "report meta cpuinfo");
is($harness->parsed_report->{report_meta}->{'ram'},                    '1887MB',                                                             "report meta ram");
is($harness->parsed_report->{report_meta}->{'starttime-test-program'}, 'Fri Jun 13 11:16:35 CEST 2008',                                      "report meta starttime test program");

is($harness->parsed_report->{db_meta}->{'suite_version'}, '2.010004',                                                                    "db meta suite version");
is($harness->parsed_report->{db_meta}->{'language_description'}, 'Perl 5.010000, /2home/ss5/perl510/bin/perl',                           "db meta language description");
is($harness->parsed_report->{db_meta}->{'machine_name'}, 'bascha',                                                                       "db meta machine name");
is($harness->parsed_report->{db_meta}->{'uname'}, 'Linux bascha 2.6.24-18-generic #1 SMP Wed May 28 19:28:38 UTC 2008 x86_64 GNU/Linux', "db meta uname");
is($harness->parsed_report->{db_meta}->{'osname'}, 'Ubuntu 8.04',                                                                        "db meta osname");
is($harness->parsed_report->{db_meta}->{'cpuinfo'}, '2 cores [AMD Athlon(tm) 64 X2 Dual Core Processor 6000+]',                          "db meta cpuinfo");
is($harness->parsed_report->{db_meta}->{'ram'}, '1887MB',                                                                                "db meta ram");
is($harness->parsed_report->{db_meta}->{'starttime_test_program'}, 'Fri Jun 13 11:16:35 CEST 2008',                                      "db meta starttime test program");

$harness = new Artemis::TAP::Harness( tap => $tap );
my $html = $harness->generate_html;
is(scalar @{$harness->parsed_report->{tap_sections}}, 10, "count sections"); # check to trigger preparation errors
