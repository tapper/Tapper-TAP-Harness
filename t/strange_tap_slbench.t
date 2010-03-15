#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;

use Artemis::TAP::Harness;
use File::Slurp 'slurp';
use Data::Dumper;
use Test::Deep;

my $tap;
my $harness;
my $interrupts_before_section;

# ============================================================
# the easy thing: no embedded YAML
# ============================================================

$tap     = slurp ("t/tap_archive_slbench.tap");
$harness = new Artemis::TAP::Harness( tap => $tap );
$harness->evaluate_report();

is( scalar @{$harness->parsed_report->{tap_sections}}, 13, "section count");
cmp_bag ([ map { $_->{section_name} } @{$harness->parsed_report->{tap_sections}}],
         [ qw/
                     artemis-meta-information
                     stats-proc-interrupts-before
                     SLBench-check_config_file
                     SLBench-check_language
                     SLBench-check_config_file1
                     SLBench-check_config_language
                     SLBench-benchmark-run
                     SLBench-results
                     stats-proc-interrupts-after
                     dmesg
                     var_log_messages
                     clocksource
                     uptime
             / ],
         "tap sections");
my $html = $harness->generate_html();

done_testing();
