package Tapper::TAP::Harness;
# ABSTRACT: Tapper - Tapper specific TAP handling

use 5.010;
use strict;
use warnings;

use TAP::Parser;
use TAP::Parser::Aggregator;
use Directory::Scratch;
use File::Temp 'tempdir', 'tempfile';
use YAML::Tiny;
use Archive::Tar;
use IO::Scalar;
use IO::String;



our @SUITE_HEADER_KEYS_GENERAL = qw(suite-version
                                    hardwaredb-systems-id
                                    machine-name
                                    machine-description
                                    reportername
                                    starttime-test-program
                                    endtime-test-program
                                  );

our @SUITE_HEADER_KEYS_DATE = qw(starttime-test-program
                                 endtime-test-program
                               );

our @SUITE_HEADER_KEYS_REPORTGROUP = qw(reportgroup-arbitrary
                                        reportgroup-testrun
                                        reportgroup-primary
                                        owner
                                      );

our @SUITE_HEADER_KEYS_REPORTCOMMENT = qw(reportcomment );

our @SECTION_HEADER_KEYS_GENERAL = qw(ram cpuinfo bios lspci lsusb uname osname uptime language-description
                                      flags changeset kernel description
                                      xen-version xen-changeset xen-dom0-kernel xen-base-os-description
                                      xen-guest-description xen-guest-test xen-guest-start xen-guest-flags xen-hvbits
                                      kvm-module-version kvm-userspace-version kvm-kernel
                                      kvm-base-os-description kvm-guest-description
                                      kvm-guest-test kvm-guest-start kvm-guest-flags
                                      simnow-svn-version
                                      simnow-version
                                      simnow-svn-repository
                                      simnow-device-interface-version
                                      simnow-bsd-file
                                      simnow-image-file
                                      ticket-url wiki-url planning-id moreinfo-url
                                      tags
                                    );

use Moose;

has tap            => ( is => 'rw', isa => 'Str' );
has tap_is_archive => ( is => 'rw' );
has parsed_report  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has section_names  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );

our $re_prove_section          = qr/^([-_\d\w\/.]*\w)\s?\.{2,}\s*$/;
our $re_tapper_meta           = qr/^#\s*((?:Tapper|Artemis)-)([-\w]+):(.+)$/i;
our $re_tapper_meta_section   = qr/^#\s*((?:Tapper|Artemis)-Section:)\s*(.+)$/i;
our $re_explicit_section_start = qr/^#\s*((?:Tapper|Artemis)-explicit-section-start:)\s*(\S*)/i;

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

# hot fix known TAP errors
sub _fix_broken_tap {
        my ($tap) = @_;

        # say STDERR "============================================================";
        # say STDERR $tap;

        # TAP::Parser chokes on that
        $tap =~ s/^(\s+---)\s+$/$1/msg;

        # known wrong YAML-in-TAP in database,
        # usually Kernbench wrapper output
        $tap =~ s/^(\s+)(jiffies)\s*$/$1Clocksource: $2/msg;
        $tap =~ s/^(\s+kvm-clock)\s*$/$1: ~/msg;
        $tap =~ s/^(\s+acpi_pm)\s*$/$1: ~/msg;
        $tap =~ s/^(\s+Cannot determine clocksource)\s*$/  Cannot_determine_clocksource: ~/msg;
        $tap =~ s/^(\s+linetail):\s*$/$1: ~/msg;
        $tap =~ s/^(\s+CPU\d+):\s*$/$1: ~/msg;
        $tap =~ s/^(\s+)(\w{3} \w{3} +\d+ \d+:\d+:\d+ \w+ \d{4})$/$1date: $2/msg;
        $tap =~ s/^(\s+)(2\.6\.\d+[^\n]*)$/$1kernel: $2/msg; # kernel version
        $tap =~ s/^(\s+)(Average)\s*([^\n]*)$/$1average: $3/msg;
        $tap =~ s/^(\s+)(Elapsed Time)\s*([^\n]*)$/$1elapsed_time: $3/msg;
        $tap =~ s/^(\s+)(User Time)\s*([^\n]*)$/$1user_time: $3/msg;
        $tap =~ s/^(\s+)(System Time)\s*([^\n]*)$/$1system_time: $3/msg;
        $tap =~ s/^(\s+)(Percent CPU)\s*([^\n]*)$/$1percent_cpu: $3/msg;
        $tap =~ s/^(\s+)(Context Switches)\s*([^\n]*)$/$1context_switches: $3/msg;
        $tap =~ s/^(\s+)(Sleeps)\s*([^\n]*)$/$1sleeps: $3/msg;

        # say STDERR "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<";
        # say STDERR $tap;
        # say STDERR ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";

        return $tap;
}

sub _parse_tap_into_sections
{
        my ($self) = shift;

        return $self->_parse_tap_into_sections_archive(@_) if $self->tap_is_archive;
        return $self->_parse_tap_into_sections_raw(@_);
}

=head2 fix_last_ok

The C<prove> tool adds an annoying last summary line, cut that away.

=cut

sub fix_last_ok { ${+shift} =~ s/\nok$// }

# return sections
sub _parse_tap_into_sections_raw
{
        my ($self) = @_;

        $self->parsed_report->{tap_sections} = [];
        $self->section_names({});

        my $report_tap = $self->tap;

        #TODO: WRONG PLACE... THAT JUST SCREWES UP TESTS
        #      and it doesn't matter. When we split into section
        #      it get lost for the later sections...
        #my $TAPVERSION = "TAP Version 13";
        #$report_tap    = $TAPVERSION."\n".$report_tap unless $report_tap =~ /^TAP Version/msi;

        $report_tap = _fix_broken_tap($report_tap);
        my $parser = new TAP::Parser ({ tap => $report_tap, version => 13 });

        my %section = ();
        $self->parsed_report->{report_meta} = {
                                               'suite-name'    => 'unknown',
                                               'suite-version' => 'unknown',
                                               'suite-type'    => 'unknown',
                                               'reportcomment' => undef,
                                              };
        my $tap_starts_with_plan         = 0;
        my $tap_starts_with_tests        = 0;
        my $tap_starts_with_prove        = 0;
        my $section_starts_with_comment  = 0;
        my $section_starts_with_prove    = 0;
        my $section_starts_explicit      = 0;
        my $last_line_was_tap            = 0;  # find multiple comments
        my $passed_none_test_line        = 0;  # find multiple test
        my $is_prove                     = 0;

        # go through every tap line
        while ( my $line = $parser->next )
        {
                # Cases which tell us if there is a new section:
                # 1. first TAP line is test => end with plan
                #    1.1 all tapper comments before the first test are matched
                #    1.2 all tapper comments after plan are matched
                # 2. first TAP line is a plan => end with new plan
                #    2.1 tapper comments before plan are matched
                #    2.2 tapper comments after plan are matched
                # 3. first TAP line is prove output => end with a prove output
                #    prove scripts are unique tests, therefore they should not contain multiple
                #    test sets

                # loop variables
                my $raw        = $line->raw;
                my $is_plan    = $line->is_plan;
                my $is_unknown = $line->is_unknown;
                my $is_test    = $line->is_test;
                my $is_comment = $line->is_comment;
                # prove output
                if ( $is_unknown and $raw =~ $re_prove_section ) {
                    $is_prove = 1;
                } else {
                    $is_prove = 0;
                }


                # start new section?
                my $newsection = 0;

                # all sections start with a tapper comment
                # therefore we have to check every comment if
                # it is a eligable tapper command
                if ($section_starts_with_comment) {
                    # There could be multiple tapper comments in a row, we need to remember when there
                    # was a none tapper comment
                    if ($raw !~ $re_tapper_meta) {
                        $last_line_was_tap = 1;
                    }

                    # we started with tapper comments and previous line was not a tap
                    if ($last_line_was_tap and $raw =~ $re_tapper_meta and $raw !~ $re_explicit_section_start) {
                        #1.1
                        if ($tap_starts_with_tests) {
                            $newsection = 1;
                        }
                        #2.1
                        if ($tap_starts_with_plan and $is_plan) {
                            $newsection = 1;
                        }
                    }
                }

                # all sections start with TAP, the tapper comments can be in the end
                # but before the new section
                if (! $section_starts_with_comment and !$section_starts_with_prove and !$section_starts_explicit) {
                    # There could be multiple tests in a row, we need to remember when there
                    # was not a test
                    if (!$is_test and $tap_starts_with_tests) {
                        $passed_none_test_line = 1;
                    }
                    # 1.2
                    if ($tap_starts_with_tests and $passed_none_test_line and $is_test) {
                        $newsection = 1;
                    }
                    # 2.2 we started with a plan and have a new plan
                    if ($tap_starts_with_plan and $is_plan) {
                        $newsection = 1;
                    }
                }

                # Is first TAP line a test, plan or prove?
                #   or do we use a lazy plan where the
                #   plan is after all the tests?
                if ($tap_starts_with_plan == 0 and $tap_starts_with_tests == 0 and $section_starts_with_prove == 0 and $section_starts_explicit == 0) {
                    if ($is_plan) {
                        $tap_starts_with_plan = 1;
                    } elsif ($is_test) {
                        $tap_starts_with_tests = 1;
                    } elsif ($is_prove) {
                        $section_starts_with_prove = 1;
                    } elsif ( $raw =~ $re_explicit_section_start) {
                        $section_starts_explicit = 1;
                    } elsif ($raw =~ $re_tapper_meta and $raw !~ $re_explicit_section_start) {
                        # comments can only be tapper comments
                        # everything else does not make sense before any tap started
                        $section_starts_with_comment = 1;
                    }
                }

                # explicite section introduction
                # we don't care if the last line was a tap version or not
                # if the last line was part of this explicit section, the provided syntax
                # is totally off
                if ( $raw =~ $re_explicit_section_start) {
                    $newsection = 1;
                }

                # that has nothing to do with TAP...
                if ($is_prove) {
                    $newsection = 1;
                }

                # did we found a new section?
                if ($newsection) {
                        if (keys %section) {
                                # Store a copy (ie., not \%section) so it doesn't get overwritten in next loop
                                # TODO: why do we need to clean it up? Shouldn't matter...
                                #   t/harness-provetap.t and t/harness.t depend on it because
                                # the tests are sensitive to this
                                # but we shouldn't need this line et al. Only uncommented due of 
                                # prove -vl t/*.t
                                fix_last_ok(\ $section{raw}) if $is_prove;
                                push @{$self->parsed_report->{tap_sections}}, { %section };
                        }
                        # reset section information
                        %section = ();
                        # we don't need to reset the other ones because
                        # mixing lazy with proper TAP plans is never appropriate and will always
                        # lead to issues
                        $last_line_was_tap            = 0;

                }


                # ----- extract some meta information -----

                # a normal TAP line
                # TODO: does it really matter that if filtering the unknown lines out?
                if ( not $is_unknown ) {
                        $section{raw} .= "$raw\n";
                }

                # looks like tapper meta line
                #TODO: do we really need to check $re_tapper_meta?
                if ( $line->is_comment and $raw =~ $re_tapper_meta )
                {
                        my $key = lc $2;
                        my $val = $3;
                        # cleanup spaces from regex, not the best style to use
                        # $2 and $3 before
                        $val =~ s/^\s+//;
                        $val =~ s/\s+$//;
                        if ($raw =~ $re_tapper_meta_section) {
                                $section{section_name} //= $self->_unique_section_name( $val );
                        }
                        $section{section_meta}{$key} = $val;              # section keys
                        $self->parsed_report->{report_meta}{$key} = $val; # also global keys, later entries win
                }

                # if we have multiple lines from prove, we use
                # them as section name... this can overwitten later
                # when there is a explicit tapper comment before the section
                # is done
                if ( $is_unknown and $raw =~ $re_prove_section )
                {
                        my $section_name = $self->_unique_section_name( $1 );
                        $section{section_name} //= $section_name;
                }

        }

        # store last section
        # TODO: why do we need to clean it up? Shouldn't matter...
        #fix_last_ok(\ $section{raw}) if $is_prove;
        push @{$self->parsed_report->{tap_sections}}, { %section } if keys %section;

        $self->fix_section_names;
}

####################################################
# TODO: CLEAN UP OLD SECTION, KEPT TO COMPARE IT WITH THE NEW ONE
####################################################
# return sections
sub _parse_tap_into_sections_raw_OLD
{
        my ($self) = @_;

        $self->parsed_report->{tap_sections} = [];
        $self->section_names({});

        my $report_tap = $self->tap;

        my $TAPVERSION = "TAP Version 13";
        $report_tap    = $TAPVERSION."\n".$report_tap unless $report_tap =~ /^TAP Version/msi;

        $report_tap = _fix_broken_tap($report_tap);
        my $parser = new TAP::Parser ({ tap => $report_tap, version => 13 });

        my $i = 0;
        my %section;
        my $looks_like_prove_output = 0;
        $self->parsed_report->{report_meta} = {
                                               'suite-name'    => 'unknown',
                                               'suite-version' => 'unknown',
                                               'suite-type'    => 'unknown',
                                               'reportcomment' => undef,
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

                # start new section?
                my $newsection = 0;
                # explicite section introduction && last line was not version
                if ( $raw =~ $re_explicit_section_start and ! $last_line_was_version ) {
                    $newsection = 1;
                }
                # section not marked explicit
                if (! $sections_marked_explicit) {
                    # but first line of entire tap
                    if ($i == 0) {
                        $newsection = 1;
                    }
                    # not proven output
                    if ( ! $looks_like_prove_output ) {
                        if ( $is_plan and not $last_line_was_version ) {
                            $newsection = 1;
                        }
                        if ( $is_version and not $last_line_was_plan ) {
                            $newsection = 1;
                        }
                    }
                    if ( $looks_like_prove_output and
                         ! $last_line_was_version and
                         ! $last_line_was_plan and
                         $raw =~ $re_prove_section) {
                        $newsection = 1;
                    }
                }

                # we have a new section
                if ($newsection) {
                        #say STDERR "____________________________ new section";
                        #say STDERR "****************************************";
                        if (keys %section) {
                                # Store a copy (ie., not \%section) so it doesn't get overwritten in next loop
                                fix_last_ok(\ $section{raw}) if $looks_like_prove_output;
                                push @{$self->parsed_report->{tap_sections}}, { %section };
                        }
                        %section = ();
                }


                # ----- extract some meta information -----

                # a normal TAP line
                if ( not $is_unknown ) {
                        $section{raw} .= "$raw\n";
                }

                # looks like tapper meta line
                #TODO: do we really need to check $re_tapper_meta?
                if ( $line->is_comment and $raw =~ $re_tapper_meta )
                {
                        my $key = lc $2;
                        my $val = $3;
                        # TODO: if we need to check for $re_tapper_meta, we don't
                        #       need the following line
                        $val =~ s/^\s+//;
                        $val =~ s/\s+$//;
                        if ($raw =~ $re_tapper_meta_section) {
                                $section{section_name} //= $self->_unique_section_name( $val );
                        }
                        $section{section_meta}{$key} = $val;              # section keys
                        $self->parsed_report->{report_meta}{$key} = $val; # also global keys, later entries win
                }

                # looks like filename line from "prove"
                if ( $is_unknown and $raw =~ $re_prove_section )
                {
                        my $section_name = $self->_unique_section_name( $1 );
                        $section{section_name} //= $section_name;
                }

                $i++;
                $last_line_was_plan    = $is_plan    ? 1 : 0;
                $last_line_was_version = $is_version ? 1 : 0;
        }

        # store last section
        fix_last_ok(\ $section{raw}) if $looks_like_prove_output;
        push @{$self->parsed_report->{tap_sections}}, { %section } if keys %section;

        $self->fix_section_names;
}

sub _get_tap_sections_from_archive
{
        my ($self) = @_;

        # some stacking to enable Archive::Tar read compressed in-memory string
        my $TARSTR       = IO::String->new($self->tap);
        my $TARZ         = IO::Zlib->new($TARSTR, "rb");
        my $tar          = Archive::Tar->new($TARZ);

        my $meta         = YAML::Tiny::Load($tar->get_content("meta.yml"));
        my @tap_sections = map {
                                my $f1 = $_;                          # original name as-is
                                my $f2 = $_; $f2 =~ s,^\./,,;         # force no-leading-dot
                                my $f3 = $_; $f3 = "./$_";            # force    leading-dot
                                local $Archive::Tar::WARN = 0;
                                my $tap = $tar->get_content($f1) // $tar->get_content($f2) // $tar->get_content($f3);
                                $tap = "# Untar Bummer!" if ! defined $tar;
                                { tap => $tap, filename => $f1 };
                               } @{$meta->{file_order}};
        return @tap_sections;
}

sub _parse_tap_into_sections_archive
{
        my ($self) = @_;

        $self->parsed_report->{tap_sections} = [];
        $self->section_names({});

        my @tap_sections = $self->_get_tap_sections_from_archive($self->tap);

        my $looks_like_prove_output = 0;
        $self->parsed_report->{report_meta} = {
                                               'suite-name'    => 'unknown',
                                               'suite-version' => 'unknown',
                                               'suite-type'    => 'unknown',
                                               'reportcomment' => undef,
                                              };

        my %section;

        foreach my $tap_file (@tap_sections)
        {

                my $tap       = $tap_file->{tap};
                my $filename  = $tap_file->{filename};

                my $parser = TAP::Parser->new ({ tap => $tap, version => 13 });

                # ----- store previous section, start new section -----

                # start new section
                if (keys %section)
                {
                        # Store a copy (ie., not \%section) so it doesn't get overwritten in next loop
                        push @{$self->parsed_report->{tap_sections}}, { %section };
                }
                %section = ();

                while ( my $line = $parser->next )
                {
                        my $raw        = $line->raw;
                        my $is_plan    = $line->is_plan;
                        my $is_version = $line->is_version;
                        my $is_unknown = $line->is_unknown;
                        my $is_yaml    = $line->is_yaml;

                        # ----- extract some meta information -----

                        # a normal TAP line and not a summary line from "prove"
                        if ( not $is_unknown )
                        {
                                $section{raw} .= "$raw\n";
                        }

                        # TODO: remove following, it is already defined with "^our $re_tapper_meta" before
                        #my $re_tapper_meta           = qr/^#\s*((?:Tapper|Artemis)-)([-\w]+):(.+)$/i;
                        # TODO: remove following, it is already defined in "^our $re_tapper_meta_section"
                        #my $re_tapper_meta_section   = qr/^#\s*((?:Tapper|Artemis)-Section:)\s*(.+)$/i;
                        # looks like tapper meta line
                        # TODO: remove the following: above is the following defined
                        #            our $re_tapper_meta = qr/^#\s*((?:Tapper|Artemis)-)([-\w]+):(.+)$/i;
                        #if ( $line->is_comment and $raw =~ m/^#\s*((?:Tapper|Artemis)-)([-\w]+):(.+)$/i ) # (
                        if ( $line->is_comment and $raw =~ $re_tapper_meta ) # (
                        {
                                # TODO: refactor inner part with _parse_tap_into_sections_raw()
                                my $key = lc $2;
                                my $val = $3;
                                $val =~ s/^\s+//;
                                $val =~ s/\s+$//;
                                if ($raw =~ $re_tapper_meta_section)
                                {
                                        $section{section_name} = $self->_unique_section_name( $val );
                                }
                                $section{section_meta}{$key} = $val; # section keys
                                $self->parsed_report->{report_meta}{$key} = $val; # also global keys, later entries win
                        }
                }
                $section{section_name} //= $self->_unique_section_name( $filename );
        }

        # store last section
        push @{$self->parsed_report->{tap_sections}}, { %section } if keys %section;

        #TODO: maybe cleaning up the following debugging parts?
        #use Data::Dumper;
        #print STDERR Dumper($self->parsed_report);
        $self->fix_section_names;
}

=head2 fix_section_names

Create sensible section names that fit further processing,
eg. substitute whitespace by dashes, fill missing names, etc.

=cut

sub fix_section_names
{
        my ($self) = @_;

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
                my $rawtap = $section->{raw} || '';
                $rawtap    = $TAPVERSION."\n".$rawtap unless $rawtap =~ /^TAP Version/msi;
                my $parser = new TAP::Parser ({ tap => $rawtap });
                $parser->run;
                # print STDERR "# " . $section->{section_name} . "\n";
                $aggregator->add( $section->{section_name} => $parser );
        }
        $aggregator->stop;

        # exit
        foreach (qw(total
                    passed
                    parse_errors
                    skipped
                    todo
                    todo_passed
                    wait
                    failed
                    todo_passed
                  ))
        {
                no strict 'refs'; ## no critic
                $self->parsed_report->{stats}{$_} = $aggregator->$_;
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

        foreach my $key (@SUITE_HEADER_KEYS_GENERAL)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_meta}{$accessor} = $value if defined $value;
        }

        foreach my $key (@SUITE_HEADER_KEYS_DATE)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_date_meta}{$accessor} = $value if defined $value;
        }

        foreach my $key (@SUITE_HEADER_KEYS_REPORTGROUP)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_reportgroup_meta}{$accessor} = $value if defined $value;
        }

        foreach my $key (@SUITE_HEADER_KEYS_REPORTCOMMENT)
        {
                my $value = $self->parsed_report->{report_meta}{$key};
                my $accessor = $key;
                $accessor =~ s/-/_/g;
                $self->parsed_report->{db_report_reportcomment_meta}{$accessor} = $value if defined $value;
        }
}

sub _process_section_meta_information
{
        my ($self) = @_;

        # section meta

        foreach my $section ( @{$self->parsed_report->{tap_sections}} ) {
                foreach my $key (@SECTION_HEADER_KEYS_GENERAL)
                {
                        use Data::Dumper;
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

=head2 evaluate_report

Actually evaluate the content of the incoming report by parsing it,
aggregate the sections and extract contained meta information.

=cut

sub evaluate_report
{
        my ($self) = @_;

        $self->_parse_tap_into_sections();
        $self->_aggregate_sections();
        $self->_process_meta_information();

}

sub _fix_generated_html
{
        my ($html) = @_;

        $html =~ s/^.*<body>//msg; # cut start
        $html =~ s,<div id="footer">Generated by TAP::Formatter::HTML[^<]*</div>,,msg; # cut footer
        # cut navigation that was meant for standalone html pages, not needed by us
        $html =~ s,<div id="menu">[\t\n\s]*<ul>[\t\n\s]*<li>[\t\n\s]*<span id="show-all">[\t\n\s]*<a href="#" title="show all tests">show all</a>[\t\n\s]*</span>[\t\n\s]*<span id="show-failed">[\t\n\s]*<a href="#" title="show failed tests only">show failed</a>[\t\n\s]*</span>[\t\n\s]*</li>[\t\n\s]*</ul>[\t\n\s]*</div>,,msg;
        $html =~ s,<th class="time">Time</th>,<th class="time">&nbsp;</th>,msg; # cut "Time" header

        return $html;
}

=head2 generate_html

Render TAP through TAP::Formatter::HTML and fix some formatting to fit
into Tapper.

=cut

sub generate_html
{
        my ($self) = @_;

        $self->evaluate_report();

        my $temp       = new Directory::Scratch (TEMPLATE => 'ATH_XXXXXXXXXXXX',
                                                 CLEANUP  => 1);
        my $dir        = $temp->mkdir("section");
        my $TAPVERSION = "TAP Version 13";
        my @files = map {
                         my $fname          = "section/".$_->{section_name};
                         my $rawtap         = $_->{raw};
                         $rawtap            = $TAPVERSION."\n".$rawtap unless $rawtap =~ /^TAP Version/msi;
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

        my $cmd = qq{cd $temp/section ; $^X $prove -vm --exec 'cat' --formatter=TAP::Formatter::HTML `find -type f | sed -e 's,^\./,,' | sort`};
        #say STDERR $cmd;
        my $html = qx( $cmd );

        $html = _fix_generated_html( $html );

        $temp->cleanup; # above CLEANUP=>1 is not enough. Trust me.

        return $html;
}

1; # End of Tapper::TAP::Harness
