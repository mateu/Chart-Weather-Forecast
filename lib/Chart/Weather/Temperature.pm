package Chart::Weather::Temperature;
use Moose;
use namespace::autoclean;
use Chart::Weather::Types qw/ State City /;

use Chart::Clicker;
use Chart::Clicker::Data::Range;
use Chart::Clicker::Data::Series;
use Chart::Clicker::Data::DataSet;
use Chart::Clicker::Drawing::ColorAllocator;
use Geometry::Primitive::Circle;
use Graphics::Primitive::Font;
use Graphics::Color::RGB;
use Number::Format;

use WWW::Mechanize;
use HTML::TreeBuilder;
use List::Util qw/ max min /;

has 'state' => (
    is       => 'ro',
    isa      => 'State',
    required => 1,
);
has 'city' => (
    is       => 'ro',
    isa      => 'City',
    required => 1,
);
has 'chart_temperature_file' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { '/tmp/temperature-forecast.png' },
);
has 'image_format' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { 'png' },
);
has 'base_URL' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub { 'http://www.wunderground.com/US/' },
);
has 'forecast_URL' => (
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build_forecast_URL {
    my $self = shift;

    return $self->base_URL . $self->state . '/' . $self->city . '.html';
}

sub create_chart {
    my $self = shift;

    # Create the chart canvas
    my $chart = Chart::Clicker->new(
        width  => 240,
        height => 160,
        format => $self->image_format,
    );

    my ( $lows, $highs ) = get_high_low_data( $self->forecast_URL );
    my ( $min_range, $max_range ) = compute_range( $lows, $highs );
    my $range_ticks = range_ticks( $min_range, $max_range );
    ( $min_range, $max_range ) = pad_range( $min_range, $max_range );

    # Control the format of numbers.
    my $number_formatter = Number::Format->new;

    # Set the domain and range
    my $domain = Chart::Clicker::Data::Range->new(
        {
            lower => 0.75,
            upper => 5.25
        }
    );
    my $range = Chart::Clicker::Data::Range->new(
        {
            lower => $min_range,
            upper => $max_range,
        }
    );

    # Set the font of the tick numbers
    my $tick_font = Graphics::Primitive::Font->new(
        {
            family         => 'Trebuchet',
            size           => 11,
            antialias_mode => 'subpixel',
            hint_style     => 'medium',

        }
    );

    # Customize Context
    my $default_ctx = $chart->get_context('default');
    $default_ctx->domain_axis->tick_values( [qw(1 2 3 4 5)] );
    $default_ctx->range_axis->tick_values($range_ticks);
    $default_ctx->domain_axis->range($domain);
    $default_ctx->range_axis->range($range);
    $default_ctx->domain_axis->format(
        sub { return $number_formatter->format_number(shift); } );
    $default_ctx->domain_axis->tick_font($tick_font);
    $default_ctx->range_axis->tick_font($tick_font);
    $default_ctx->range_axis->format(
        sub { return $number_formatter->format_number(shift); } );
    $default_ctx->renderer( Chart::Clicker::Renderer::Line->new );
    $default_ctx->renderer->shape(
        Geometry::Primitive::Circle->new( { radius => 3, } ) );
    $default_ctx->renderer->brush->width(1);

    # Data series including references lines at 0 and 32.
    my $high_series = Chart::Clicker::Data::Series->new(
        keys   => [ 1, 2, 3, 4, 5 ],
        values => $highs,
    );
    my $low_series = Chart::Clicker::Data::Series->new(
        keys   => [ 1, 2, 3, 4, 5 ],
        values => $lows,
    );
    my $freezing_line = Chart::Clicker::Data::Series->new(
        keys => [ 1, 2, 3, 4, 5 ],
        values => [ (32) x 5 ],
    );
    my $zero_line = Chart::Clicker::Data::Series->new(
        keys => [ 1, 2, 3, 4, 5 ],
        values => [ (0) x 5 ],
    );

    my $title_text =
      $self->city . ' ' . $self->state . ' - Temperature Forecast';
    $chart->title->text($title_text);
    $chart->title->font->size(12);
    $chart->grid_over(1);
    $chart->plot->grid->show_range(0);
    $chart->plot->grid->show_domain(0);
    $chart->legend->visible(0);
    $chart->border->width(0);

    # Initialize some colors
    my $red = Graphics::Color::RGB->new(
        {
            red   => .75,
            green => 0,
            blue  => 0,
            alpha => .8
        }
    );
    my $blue = Graphics::Color::RGB->new(
        {
            red   => 0,
            green => 0,
            blue  => .75,
            alpha => .8
        }
    );
    my $light_blue = Graphics::Color::RGB->new(
        {
            red   => 0,
            green => 0,
            blue  => .95,
            alpha => .16
        }
    );

    # Build a new dataset object to which we add series and colors.
    my $dataset = Chart::Clicker::Data::DataSet->new;

    # build the color allocator
    my $color_allocator = Chart::Clicker::Drawing::ColorAllocator->new;
    $dataset->add_to_series($high_series);
    $color_allocator->add_to_colors($red);
    $dataset->add_to_series($low_series);
    $color_allocator->add_to_colors($blue);

    # Add freezing line when appropriate.
    if ( $min_range <= 32 ) {
        $dataset->add_to_series($freezing_line);
        $color_allocator->add_to_colors($light_blue);
    }

    # Add zero line when appropriate.
    if ( $min_range <= 0 ) {
        $dataset->add_to_series($zero_line);
        $color_allocator->add_to_colors($light_blue);
    }

    # add the dataset to the chart
    $chart->add_to_datasets($dataset);

    # assign the color allocator to the chart
    $chart->color_allocator($color_allocator);

    # write the chart to a file
    $chart->write_output( $self->chart_temperature_file );

}

=head1 Subroutines

=head2 get_high_low_data

Get the high and low temperature forecast numbers

=cut

sub get_high_low_data {
    my $forecast_data_url = shift;

    my ( @lows, @highs );
    my %numbers;
    for my $i ( -40 .. 120 ) {
        $numbers{$i} = $i;
    }
    my $mech = WWW::Mechanize->new();
    $mech->get($forecast_data_url);
    die $mech->response->status_line unless $mech->success;
    my $content = $mech->{content};

    my $page_tree = HTML::TreeBuilder->new_from_content( $mech->{content} );
    my @high_temps =
      $page_tree->look_down( '_tag', 'span', 'style', 'color: #900;' );
    foreach my $high (@high_temps) {
        my $high_text = $high->as_trimmed_text;
        if ( my ($high_temp) = $high_text =~ m{(-?\d+).*F$} ) {
            push @highs, $numbers{$high_temp};
        }
    }
    my @low_temps =
      $page_tree->look_down( '_tag', 'span', 'style', 'color: #009;' );
    foreach my $low (@low_temps) {
        my $low_text = $low->as_trimmed_text;
        if ( my ($low_temp) = $low_text =~ m{(-?\d+).*F$} ) {
            push @lows, $numbers{$low_temp};
        }
    }
    return ( \@lows, \@highs );
}

=head2 compute_range

Compute the max and min values for the y-axis (range).

=cut

sub compute_range {
    my ( $lows, $highs ) = @_;

    my $min_temperature = min @{$lows};
    my $max_temperature = max @{$highs};

    # Find nearest factor of 10 above and below
    $max_temperature += 10 - ( $max_temperature % 10 );
    $min_temperature -= ( $min_temperature % 10 );

    return ( $min_temperature, $max_temperature );
}

=head2 pad_range

Add just a touch of padding in case a value is right on the computed range.
This keeps data from being cropped off in the graph.

=cut

sub pad_range {
    my ( $min_range, $max_range ) = @_;

    my $padding = 2;
    return ( ( $min_range - $padding ), ( $max_range + $padding ) );
}

=head2 range_ticks

Determine where the ticks for the y-axis will be based on the high and low temperatures

=cut

sub range_ticks {
    my ( $low, $high ) = @_;
    my $delta = $high - $low;
    my $tens  = int( $delta / 10 );
    my @ticks = ($low);
    for my $factor ( 1 .. $tens ) {
        push @ticks, ( $low + ( $factor * 10 ) );
    }
    return \@ticks;
}

__PACKAGE__->meta->make_immutable;
1

__END__

=head1 Authors

Mateu Hunter C<hunter@missoula.org>

=head1 Copyright

Copyright 2010, Mateu Hunter

=head1 License

You may distribute this code under the same terms as Perl itself.

=cut
