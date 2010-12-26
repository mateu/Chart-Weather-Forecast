use Chart::Weather::Forecast::Temperature;
use Weather::WWO;

my $api_key = 'faa2489de6022450101712';
my $zip     = '59802';
my $wwo     = Weather::WWO->new(
    api_key           => $api_key,
    location          => $zip,
    temperature_units => 'F',
    wind_units        => 'Miles',
);
my ( $highs, $lows ) = $wwo->forecast_temperatures;
my $forecast = Chart::Weather::Forecast::Temperature->new(
    highs      => $highs,
    lows       => $lows,
    title_text => "$zip Temperature Forcecast",
);
$forecast->create_chart;
