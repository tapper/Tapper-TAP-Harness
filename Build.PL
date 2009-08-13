use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new
    (
     module_name         => 'Artemis::TAP::Harness',
     license             => 'restrictive',
     dist_author         => 'OSRC SysInt Team <osrc-sysint@elbe.amd.com>',
     dist_version_from   => 'lib/Artemis/TAP/Harness.pm',
     build_requires => {
                        'Test::More'  => 0,
                        'File::Slurp' => 0,
                        'TAP::DOM'    => 0,
                       },
     requires => {
                  'Moose'                   => 0,
                  'TAP::Parser'             => 0,
                  'TAP::Parser::Aggregator' => 0,
                  'Directory::Scratch'      => 0,
                  'TAP::Formatter::HTML'    => '0.04',
                 },
     add_to_cleanup      => [ 'Artemis-TAP-Harness-*' ],
    );

$builder->create_build_script();
