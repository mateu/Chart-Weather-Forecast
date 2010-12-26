use Chart::Weather::Forecast::Temperature;
use Try::Tiny;
use Test::More;

my $highs = [ 37, 28, 17, 22, 28 ];
my $lows  = [ 18, 14, -4,  10, 18 ];
my $have_issues = 0;

try {
    my $forecast = Chart::Weather::Forecast::Temperature->new(
        highs      => $highs,
        lows       => $lows,
        title_text => "5-day Temperature Forcecast",
    );
    $forecast->create_chart;
}
catch {
    $have_issues = 1;
};

is($have_issues, 0, 'No errors thrown while calling new and create_chart');

done_testing();
