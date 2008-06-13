use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Artemis::TAP::Harness',
    license             => 'restrictive',
    dist_author         => 'OSRC SysInt Team <osrc-sysint@elbe.amd.com>',
    dist_version_from   => 'lib/Artemis/TAP/Harness.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Artemis-TAP-Harness-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
