use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Chart::Weather::Temperature;

my $forecast = Chart::Weather::Temperature->new ( city => 'Boston', state => 'MA');
$forecast->create_chart;
