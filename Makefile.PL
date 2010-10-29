use strict;
use warnings;

use inc::Module::Install;

name     'Artemis-TAP-Harness';
all_from 'lib/Artemis/TAP/Harness.pm';
author   'OSRC SysInt Team <osrc-sysint@elbe.amd.com>';
license  'freebsd';

build_requires 'Test::More'         => 0;
build_requires 'Test::Perl::Critic' => 0;
build_requires 'File::Slurp'        => 0;
build_requires 'TAP::DOM'           => 0;

requires 'Moose'                   => 0;
requires 'Test::Harness'           => '3.22';
requires 'TAP::Parser'             => 0;
requires 'TAP::Parser::Aggregator' => 0;
requires 'Directory::Scratch'      => 0;
requires 'TAP::Formatter::HTML'    => '0.04';
requires 'YAML::Tiny'              => 0;
requires 'Archive::Tar'            => 0;
requires 'IO::Scalar'              => 0;
requires 'IO::String'              => 0;

WriteAll;

