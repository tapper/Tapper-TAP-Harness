#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';
use Data::Dumper;
use TAP::DOM;

plan tests => 16;

# ============================================================

my $tap = slurp ("t/tap_archive_headers_kvm.tap");
my $harness = new Artemis::TAP::Harness( tap => $tap );

$harness->evaluate_report();

is(scalar @{$harness->parsed_report->{tap_sections}}, 4, "count sections");

is($harness->parsed_report->{report_meta}{'suite-name'},    'Daily-Report',  "report meta suite name");
is($harness->parsed_report->{report_meta}{'suite-version'}, '0.01',          "report meta suite version");
is($harness->parsed_report->{report_meta}{'machine-name'},  'kepek',         "report meta machine name");

# sections
is($harness->parsed_report->{tap_sections}[0]{section_name},'Metainfo',                     "section name 0");
is($harness->parsed_report->{tap_sections}[1]{section_name},'KVM-Metainfo',                 "section name 1");
is($harness->parsed_report->{tap_sections}[2]{section_name},'guest_1_ms_vista_32b_up_qcow', "section name 2");
is($harness->parsed_report->{tap_sections}[3]{section_name},'host',                         "section name 3");

# kvm meta
is($harness->parsed_report->{tap_sections}[1]{section_meta}{'kvm-module-version'}, 'kvm-84-6620-ge3dbe3f', "section 1 meta kvm-module-version");
is($harness->parsed_report->{tap_sections}[1]{section_meta}{'kvm-userspace-version'}, 'kvm-84-488-gee8b55c', "section 1 meta kvm-userspace-version");
is($harness->parsed_report->{tap_sections}[1]{section_meta}{'kvm-base-os-description'}, 'Fedora release 10 (Cambridge)', "section 1 meta kvm-base-os-description");
is($harness->parsed_report->{tap_sections}[1]{section_meta}{'kvm-kernel'}, '2.6.27.21-170.2.56.fc10.x86_64 x86_64', "section 1 meta kvm-kernel");

# kvm guest meta
is($harness->parsed_report->{tap_sections}[2]{section_meta}{'kvm-guest-description'}, '001-WinSST', "section 2 meta kvm-guest-description");
is($harness->parsed_report->{tap_sections}[2]{section_meta}{'kvm-guest-test'}, 'WinSST-4.7.4', "section 2 meta kvm-guest-test");
is($harness->parsed_report->{tap_sections}[2]{section_meta}{'kvm-guest-start'}, '2009-04-06 19:52:18', "section 2 meta kvm-guest-start");
is($harness->parsed_report->{tap_sections}[2]{section_meta}{'kvm-guest-flags'}, '-m 2304 -smp 1', "section 2 meta kvm-guest-flags");

# ============================================================

