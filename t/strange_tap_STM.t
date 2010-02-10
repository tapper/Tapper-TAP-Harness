#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';
use Data::Dumper;
use Test::Deep;

plan tests => 1;

my $tap;
my $harness;
my $interrupts_before_section;

# ============================================================

$tap     = slurp ("t/tap_archive_STM_explicit_section.tap");
$harness = new Artemis::TAP::Harness( tap => $tap );
$harness->evaluate_report();

is( scalar @{$harness->parsed_report->{tap_sections}}, 1, "section count");
# cmp_bag ([ map { $_->{section_name} } @{$harness->parsed_report->{tap_sections}}],
#          [
#           qw/
#                     metainfo
#                     kerneltype
#                     uptime
#                     misc
#             /
#          ],
#          "tap sections");

my $metainfo = $harness->parsed_report->{tap_sections}->[0];
diag Dumper $metainfo;

# is ($metainfo->{section_name}, 'misc', "oprofile section name misc");

# like ($harness->parsed_report->{tap_sections}->[2]->{raw}, qr/uptime: 0:00/, "uptime raw contains YAML");
# like ($harness->parsed_report->{tap_sections}->[3]->{raw}, qr/misc bar/, "misc raw contains tests");

# # ============================================================

# $tap     = slurp ("t/tap_archive_oprofile_reallive.tap");
# $harness = new Artemis::TAP::Harness( tap => $tap );
# $harness->evaluate_report();

# my $html = $harness->generate_html();
# if (open my $F, ">", "/tmp/ATH_oprofile.html") {
#         print $F $html;
#         close $F;
# }

# #print STDERR Dumper($harness->parsed_report->{tap_sections});
# # foreach (map { $_->{section_name} }  @{$harness->parsed_report->{tap_sections}})
# # {
# #         diag "Section: $_";
# # }

# is( scalar @{$harness->parsed_report->{tap_sections}}, 9, "oprofile section count");
# #                    version.tap
# #                    reportgroup.tap
# cmp_bag ([ map { $_->{section_name} } @{$harness->parsed_report->{tap_sections}}],
#          [
#           qw/
#                     metainfo
#                     kerneltype
#                     uptime
#                     kernel-todo
#                     kernel-kernel
#                     clean-todo
#                     clean-clean
#                     oprofile-todo
#                     oprofile-oprofile
#             /
#          ],
#          "tap sections");

# $metainfo = $harness->parsed_report->{tap_sections}->[3];
# is ($metainfo->{section_name}, 'kernel-todo', "oprofile section name misc");

# like ($harness->parsed_report->{tap_sections}->[2]->{raw}, qr/uptime: 0:00/, "uptime raw contains YAML");
# like ($harness->parsed_report->{tap_sections}->[4]->{raw}, qr/update AMD Northbridge events access control policy/ms, "kernel-todo raw contains expected text");
