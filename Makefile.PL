use strict;
use warnings;

use inc::Module::Install;

name     'Tapper-TAP-Harness';
all_from 'lib/Tapper/TAP/Harness.pm';
author   'AMD OSRC Tapper Team <tapper@amd64.org>';
license  'freebsd';

build_requires 'Test::More'         => 0;
build_requires 'Test::Perl::Critic' => 0;
build_requires 'File::Slurp'        => 0;
build_requires 'TAP::DOM'           => 0;
build_requires 'Tapper::Test' => "3.000010";

author_requires 'Module::Install::WriteAll';

requires 'Moose'                   => 0;
requires 'Test::Harness'           => '3.22';
requires 'TAP::Parser'             => "3.23";
requires 'TAP::Parser::Aggregator' => 0;
requires 'Directory::Scratch'      => 0;
requires 'TAP::Formatter::HTML'    => '0.04';
requires 'YAML::Tiny'              => 0;
requires 'Archive::Tar'            => "1.76";
requires 'IO::Scalar'              => 0;
requires 'IO::String'              => 0;
requires 'IO::Zlib'                => 0;

repository 'git://github.com/amd/Tapper-TAP-Harness.git';
bugtracker 'http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tapper-TAP-Harness';

WriteAll;

