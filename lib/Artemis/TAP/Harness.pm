package Artemis::TAP::Harness;

use 5.010;

use strict;
use warnings;

use TAP::Parser;
use TAP::Parser::Aggregator;
use Directory::Scratch;

our $VERSION = '2.010026';

use Moose;

has tap           => ( is => 'rw', isa => 'Str'     );
has parsed_report => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has section_names => ( is => 'rw', isa => 'HashRef', default => sub {{}} );

sub _get_prove {
        my $prove = $^X;
        $prove =~ s/perl[\d.]*$/prove/;
        return $prove;
}

# report a uniqe section name
sub _unique_section_name
{
        my ($self, $section_name) = @_;

        my $trail_number = 1;
        if (defined $self->section_names->{$section_name}
            and not $section_name =~ m/\d$/)
        {
                $section_name .= $trail_number;
        }
        while (defined $self->section_names->{$section_name}) {
                $trail_number++;
                $section_name =~ s/\d+$/$trail_number/;
        }
        $self->section_names->{$section_name} = 1;
        return $section_name;
}

# return sections
sub _parse_tap_into_sections
{
        my ($self) = @_;

        $self->parsed_report->{tap_sections} = [];
        $self->section_names({});

        my $report_tap = $self->tap;

        my $TAPVERSION = "TAP Version 13";
        $report_tap    = $TAPVERSION."\n".$report_tap unless $report_tap =~ /^TAP Version/ms;

        #say STDERR "============================================================";
        #say STDERR $report_tap;
        # hot fix TAP errors
        $report_tap =~ s/^(\s+jiffies)\s*$/$1: ~/msg;
        $report_tap =~ s/^(\s+kvm-clock)\s*$/$1: ~/msg;
        $report_tap =~ s/^(\s+acpi_pm)\s*$/$1: ~/msg;
        $report_tap =~ s/^(\s+Cannot determine clocksource)\s*$/  Cannot_determine_clocksource: ~/msg;
        $report_tap =~ s/^(\s+linetail):\s*$/$1: ~/msg;
        $report_tap =~ s/^(\s+CPU\d+):\s*$/$1: ~/msg;
        $report_tap =~ s/^(\s+)(\w{3} \w{3} +\d+ \d+:\d+:\d+ \w+ \d{4})$/$1date: $2/msg;
        $report_tap =~ s/^(\s+)(2\.6\.\d+[^\n]*)$/$1kernel: $2/msg; # kernel version
        $report_tap =~ s/^(\s+)(Average)\s*([^\n]*)$/$1average: $3/msg;
        $report_tap =~ s/^(\s+)(Elapsed Time)\s*([^\n]*)$/$1elapsed_time: $3/msg;
        $report_tap =~ s/^(\s+)(User Time)\s*([^\n]*)$/$1user_time: $3/msg;
        $report_tap =~ s/^(\s+)(System Time)\s*([^\n]*)$/$1system_time: $3/msg;
        $report_tap =~ s/^(\s+)(Percent CPU)\s*([^\n]*)$/$1percent_cpu: $3/msg;
        $report_tap =~ s/^(\s+)(Context Switches)\s*([^\n]*)$/$1context_switches: $3/msg;
        $report_tap =~ s/^(\s+)(Sleeps)\s*(\d+.\d+ \(\d+.\d+\)[^\n]*)$/$1sleeps: $3/msg;

#         say STDERR "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<";
#         say STDERR $report_tap;
#         say STDERR ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
        my $parser = new TAP::Parser ({ tap => $report_tap });

        my $i = 0;
        my %section;
        my $looks_like_prove_output = 0;
        my $re_prove_section          = qr/^([-_\d\w\/.]*\w)\s?\.{2,}$/;
        my $re_artemis_meta           = qr/^#\s*(Artemis-)([-\w]+):(.+)$/i;
        my $re_artemis_meta_section   = qr/^#\s*(Artemis-Section:)\s*(.+)$/i;
        my $re_explicit_section_start = qr/^#\s*(Artemis-explicit-section-start:)(.*)$/i;
        $self->parsed_report->{report_meta} = {
                                               'suite-name'    => 'unknown',
                                               'suite-version' => 'unknown',
                                               'suite-type'    => 'unknown',
                                              };
        my $sections_marked_explicit     = 0;
        my $last_line_was_version        = 0;
        my $last_line_was_plan           = 0;

        while ( my $line = $parser->next )
        {
                my $raw        = $line->raw;
                my $is_plan    = $line->is_plan;
                my $is_version = $line->is_version;
                my $is_unknown = $line->is_unknown;
                my $is_yaml    = $line->is_yaml;

                #say STDERR "__".$line->raw;
                # prove section
                if ( $is_unknown and $raw =~ $re_prove_section ) {
                        $looks_like_prove_output ||= 1;
                }

                # ----- store previous section, start new section -----

                $sections_marked_explicit = 1 if $raw =~ $re_explicit_section_start;

#                 say STDERR "    $raw";
#                 say STDERR "    $i. is_version:              $is_version";
#                 say STDERR "    $i. is_yaml:                 $is_yaml";
#                 say STDERR "    $i. looks_like_prove_output: $looks_like_prove_output";
#                 say STDERR "    $i. last_line_was_plan:      $last_line_was_plan";
#                 say STDERR "    $i. last_line_was_version:   $last_line_was_version";

                # start new section
                if ( $raw =~ $re_explicit_section_start and ! $last_line_was_version
                     or
                     (! $sections_marked_explicit
                      and ( $i == 0 or
                            ( ! $looks_like_prove_output
                              and
                              (
                               ( $is_plan and not $last_line_was_version ) or
                               ( $is_version and not $last_line_was_plan )
                              )
                            ) or
                            ( $looks_like_prove_output and
                              ! $last_line_was_version and
                              ! $last_line_was_plan and
                              $raw =~ $re_prove_section
                            ) ) ) )
                {
#                         say STDERR "____________________________ new section";

                        #say STDERR "****************************************";
                        if (keys %section) {
                                # Store a copy (ie., not \%section) so it doesn't get overwritten in next loop
                                push @{$self->parsed_report->{tap_sections}}, { %section };
                        }
                        %section = ();
                }


                # ----- extract some meta information -----

                # a normal TAP line and not a summary line from "prove"
                if ( not $is_unknown and not ($looks_like_prove_output and $raw =~ /^ok$/) ) {
                        $section{raw} .= "$raw\n";
                }

                # looks like filename line from "prove"
                if ( $is_unknown and $raw =~ $re_prove_section )
                {
                        my $section_name = $self->_unique_section_name( $1 );
                        $section{section_name} //= $section_name;
                }

                # looks like artemis meta line
                if ( $line->is_comment and $raw =~ $re_artemis_meta )
                {
                        my $key = lc $2;
                        my $val = $3;
                        $val =~ s/^\s+//;
                        $val =~ s/\s+$//;
                        if ($raw =~ $re_artemis_meta_section) {
                                my $section_name = $self->_unique_section_name( $val );
                                $section{section_name} //= $section_name;
                        }
                        $section{section_meta}{$key} = $val;              # section keys
                        $self->parsed_report->{report_meta}{$key} = $val; # also global keys, later entries win
                }

                $i++;
                $last_line_was_plan    = $is_plan    ? 1 : 0;
                $last_line_was_version = $is_version ? 1 : 0;
        }

        # store last section
        push @{$self->parsed_report->{tap_sections}}, { %section } if keys %section;

        # augment section names
        for (my $i = 0; $i < @{$self->parsed_report->{tap_sections}}; $i++)
        {
                $self->parsed_report->{tap_sections}->[$i]->{section_name} //= sprintf("section-%03d", $i);
        }

        # delete whitespace from section names
        for (my $i = 0; $i < @{$self->parsed_report->{tap_sections}}; $i++)
        {
                $self->parsed_report->{tap_sections}->[$i]->{section_name} =~ s/\s/-/g;
        }
}

sub _aggregate_sections
{
        my ($self) = @_;

        my $aggregator = new TAP::Parser::Aggregator;

        my $TAPVERSION = "TAP Version 13";

        $aggregator->start;
        foreach my $section (@{$self->parsed_report->{tap_sections}})
        {
                my $rawtap = $section->{raw};
                $rawtap    = $TAPVERSION."\n".$rawtap unless $rawtap =~ /^TAP Version/ms;
                my $parser = new TAP::Parser ({ tap => $rawtap });
                $parser->run;
                $aggregator->add( $section->{section_name} => $parser );
        }
        $aggregator->stop;

        foreach (qw(total
                    passed
                    parse_errors
                    skipped
                    todo
                    todo_passed
                    wait
                    exit
                    failed
                    todo_passed
                  ))
        {
                no strict 'refs';
                $self->parsed_report->{stats}{total} = $aggregator->$_;
        }
        $self->parsed_report->{stats}{successgrade}  = $aggregator->get_status;
        $self->parsed_report->{stats}{success_ratio} = sprintf("%02.2f",
                                                               $aggregator->total ? ($aggregator->passed / $aggregator->total * 100) : 100
                                                              );
}

sub _process_suite_meta_information
{
        my ($self) = @_;

        # suite meta

        my @suite_keys = qw(suite-version
                            machine-name
                            machine-description
                            starttime-test-program
                            endtime-test-program
                          );
        foreach my $key (@suite_keys)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_meta}{$accessor} = $value if defined $value;
        }

        my @suite_date_keys = qw(
                                        starttime-test-program
                                        endtime-test-program
                               );
        foreach my $key (@suite_date_keys)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_date_meta}{$accessor} = $value if defined $value;
        }

        my @suite_reportgroup_keys = qw(
                                               reportgroup-arbitrary
                                               reportgroup-testrun
                                               reportgroup-primary
                                      );
        foreach my $key (@suite_reportgroup_keys)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_reportgroup_meta}{$accessor} = $value if defined $value;
        }
}

sub _process_section_meta_information
{
        my ($self) = @_;

        # section meta

        my @section_keys = qw(
                                     ram cpuinfo lspci uname osname uptime language-description
                                     xen-version xen-changeset xen-dom0-kernel xen-base-os-description
                                     xen-guest-description xen-guest-test xen-guest-start xen-guest-flags
                                     kvm-module-version kvm-userspace-version kvm-kernel
                                     kvm-base-os-description kvm-guest-description
                                     kvm-guest-test kvm-guest-start kvm-guest-flags
                                     flags reportcomment
                            );
        foreach my $section ( @{$self->parsed_report->{tap_sections}} ) {
                foreach my $key (@section_keys)
                {
                        my $section_name = $section->{section_name};
                        my $value        = $section->{section_meta}{$key};
                        my $accessor     = $key;
                        $accessor        =~ s/-/_/g;
                        $section->{db_section_meta}{$accessor} = $value if defined $value;
                }
        }
}

sub _process_meta_information
{
        my ($self) = @_;

        $self->_process_suite_meta_information;
        $self->_process_section_meta_information;

}

sub evaluate_report
{
        my ($self) = @_;

        $self->_parse_tap_into_sections();
        $self->_aggregate_sections();
        $self->_process_meta_information();

}

sub generate_html
{
        my ($self) = @_;

        $self->_parse_tap_into_sections();
        $self->_aggregate_sections();
        $self->_process_meta_information();

        my $temp       = new Directory::Scratch (CLEANUP  => 0);
        my $dir        = $temp->mkdir("section");
        my $TAPVERSION = "TAP Version 13";

        my @files = map {
                         my $fname          = "section/".$_->{section_name};
                         my $rawtap         = $_->{raw};
                         $rawtap            = $TAPVERSION."\n".$rawtap unless $rawtap =~ /^TAP Version/ms;
                         my $script_content = $rawtap;
                         my $file           = $temp->touch($fname, $script_content);

#                          say STDERR "--------------------------------------------------";
#                          say STDERR $_->{raw};
#                          say STDERR "--------------------------------------------------";
#                          say STDERR $rawtap;
#                          say STDERR "--------------------------------------------------";
#                          say STDERR $script_content;
#                          say STDERR "--------------------------------------------------";
#                          say STDERR "$temp/$fname";
#                          say STDERR "--------------------------------------------------";
#                          #sleep 10;

                         [ "$temp/$fname" => $_->{section_name} ];
                        } @{$self->parsed_report->{tap_sections}};

        # Currently a TAP::Formatter::* is only usable via the
        # TAP::Harness which in turn is easiest to use externally on
        # unix shell level
        my $prove = _get_prove();

        my $html = qx( cd $temp/section ; $prove -vm --exec 'cat' --formatter=TAP::Formatter::HTML `find -type f | sort` );

        $html =~ s/^.*<body>//msg; # cut start
        $html =~ s,<div id="footer">Generated by TAP::Formatter::HTML[^<]*</div>,,msg; # cut footer
        $html =~ s,<div id="menu">[\t\n\s]*<li>[\t\n\s]*<span id="show-all"><a href="#" title="show all tests">show all</a></span>[\t\n\s]*<span id="show-failed"><a href="#" title="show failed tests only">show failed</a></span>[\t\n\s]*</li>[\t\n\s]*</div>,,msg; # cut navi
        $html =~ s,<th class="time">Time</th>,<th class="time">&nbsp;</th>,msg; # cut "Time" header

        #say STDERR "********** SLEEP"; sleep 10;
        $temp->cleanup;
        return $html;
}

1;

=head1 NAME

Artemis::TAP::Harness - Artemis specific TAP handling

=head1 SYNOPSIS

    use Artemis::TAP::Harness;
    my $foo = Artemis::TAP::Harness->new();
    ...

=head1 COPYRIGHT & LICENSE

Copyright 2008 OSRC SysInt Team, all rights reserved.

This program is released under the following license: restrictive


=cut

1; # End of Artemis::TAP::Harness
