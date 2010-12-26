use inc::Module::Install;

name 'Chart-Weather';

abstract 'Forecast Weather Charts';
author 'Mateu X Hunter';
license 'perl';
version_from 'lib/Chart/Weather.pm';

requires(
    'Data::Dumper::Concise' => 0,
    'Moose'                 => '1.21',
    'namespace::autoclean'  => 0,
    'Chart::Clicker'        => '2.65',
    'Number::Format'        => 0,
    'List::Util'            => 0,
);

auto_install;
WriteAll;
