#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';
use Data::Dumper;
use Test::Deep;

plan tests => 5;

my $tap;
my $harness;
my $interrupts_before_section;

# ============================================================

$tap     = slurp ("t/tap_archive_oprofile_explicit_sections.tap");
$harness = new Artemis::TAP::Harness( tap => $tap );
$harness->evaluate_report();

#print STDERR Dumper($harness->parsed_report->{tap_sections});
# foreach (map { $_->{section_name} }  @{$harness->parsed_report->{tap_sections}})
# {
#         diag "Section: $_";
# }

is( scalar @{$harness->parsed_report->{tap_sections}}, 4, "oprofile section count");
cmp_bag ([ map { $_->{section_name} } @{$harness->parsed_report->{tap_sections}}],
         [
          qw/
                    metainfo
                    kerneltype
                    uptime
                    misc
            /
         ],
         "tap sections");

my $metainfo = $harness->parsed_report->{tap_sections}->[3];
is ($metainfo->{section_name}, 'misc', "oprofile section name misc");

like ($harness->parsed_report->{tap_sections}->[2]->{raw}, qr/uptime: 0:00/, "uptime raw contains YAML");
like ($harness->parsed_report->{tap_sections}->[3]->{raw}, qr/misc bar/, "misc raw contains tests");

