use inc::Module::Install;

name 'Chart-Weather-Forecast';

abstract 'Forecast Weather Charts';
author 'Mateu X Hunter';
license 'perl';
version_from 'lib/Chart/Weather.pm';

requires(
    'Chart::Clicker'        => '2.65',
    'Data::Dumper::Concise' => 0,
    'List::Util'            => 0,
    'Moose'                 => '1.21',
    'namespace::autoclean'  => 0,
    'Number::Format'        => 0,
    'Path::Class'           => 0,
);

test_requires(
    'Try::Tiny'     => 0,
    'Image::Imlib2' => 0,
);

auto_install;
WriteAll;
