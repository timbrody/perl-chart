package Chart::Render;

use Carp;
use Math::Trig;
use Exporter;

use constant {
	OP_SUBSCRIPT => 0x0001,
	OP_SUPERSCRIPT => 0x0002,

	SS_SCALAR => 1.33,
};

@ISA = qw( Exporter );
@EXPORT = qw();
@EXPORT_OK = qw(
	OP_SUBSCRIPT
	OP_SUPERSCRIPT
);
%EXPORT_TAGS = (
	ops => [qw(
		OP_SUBSCRIPT
		OP_SUPERSCRIPT
	)],
);

use strict;

=head1 NAME

B<Chart::Render> - rendering surface for chart

=head1 METHODS

=over 4

=cut

=item $surface = Chart::Render->new( $format, $width, $height )

Returns a new surface for format $format of $width x $height points/pixels.

=cut

sub new
{
	my( $class, $format, $width, $height ) = @_;

	return $class->get_class->new( $format, $width, $height );
}

=item $class = Chart::Render->get_class()

Returns the render class to use, based on best graphics library available.

=cut

sub get_class
{
	eval "use Chart::Render::Cairo";
	print $@ if $@;
	return "Chart::Render::Cairo" unless $@;
	eval "use Chart::Render::GD";
	return "Chart::Render::GD" unless $@;
	
	Carp::croak "No rendering library available.";
}

=item @formats = Chart::Render::available_formats()

Returns a list of possible formats the rendering library supports.

=cut

sub formats { () }

=item Chart::Render->new( $format, $w, $h )

Create a new render surface for rendering to $format of size ($w,$h).

=cut

sub _string_ops
{
	my( $self, $string ) = @_;

	return (\0, split /\0(.)/, $string);
}

sub _color_pattern
{
	my( $self, $color, $pattern ) = @_;

	my $img = $pattern->get_surface;
	my $w = $img->get_width;
	my $h = $img->get_height;
	my $surface = $self->new( 'png', $w, $h );
	$surface->filled_rectangle( $color, 0, 0, 0, $w, $h );
	$surface->filled_rectangle( $pattern, 0, 0, 0, $w, $h );

	return $self->pattern_from_png( $surface->png );
}

=item $bytes = $r->render()

Render and return the content of the surface as bytes.

=cut

sub render {}

=back

=head2 Drawing Methods

=over 4

=item $r->arc( $color, $thickness, $x, $y, $w, $h, $s, $e )

Draw an arc with centre at ($x,$y) within an elipse ($w,$h) of size starting at $s and ending at $e (in radians).

=cut

sub arc($$$$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e ) = @_;
}

=item $r->clip( $x, $y, $x2, $y2 )

Set a rectangular clipping region between $x,$y and $x2,$y2. While this is in effect nothing can be drawn beyond this region.

=cut

sub clip
{
	my( $self, $x, $y, $x2, $y2 ) = @_;
}

=item $r->continuous( $color, $thickness, $points )

Draw a continuous line along $points.

=cut

sub continuous($$$$)
{
	my( $self, $color, $thickness, $points ) = @_;
}

=item $r->filled_arc( $color, $thickness, $x, $y, $w, $h, $s, $e )

Draw a filled arc with centre at ($x,$y) within an elipse ($w,$h) of size starting at $s and ending at $e (in radians).

=cut

sub filled_arc($$$$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e ) = @_;
}

=item $r->filled_polygon( $color, $thickness, $points )

Draw a filled polygon along $points.

$color may be a pattern.

=cut

sub filled_polygon($$$$)
{
	my( $self, $color, $thickness, $points ) = @_;
}

=item $r->filled_rectangle( $color, $thickness, $x, $y, $x2, $y2 )

Draw a filled rectangle between ($x,$y) and ($x2,$y2).

=cut

sub filled_rectangle($$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $x2, $y2 ) = @_;
}

=item $r->filled_segment( $color, $thickness, $x,$y, $w,$h, $s,$e [, $cw,$ch ] )

Draw a filled segment whose origin is $x,$y of dimensions $w,$h starting at $s clockwise to $e (in radians).

If $cw,$ch are given these are used as a core radius from which to start the segment (creating a doughnut slice).

=cut

sub filled_segment
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e, $cw, $ch ) = @_;
}

=item $r->line( $color, $thickness, $x, $y, $x2, $y2 )

Draw a line along between $x,$y and $x2,$y2.

=cut

sub line($$$$)
{
	my( $self, $color, $thickness, $x, $y, $x2, $y2 ) = @_;
}

=item $pattern = Chart::Render->pattern_from_png( $data [, %opts ] )

Create a new pattern from $data in PNG format.

=cut

sub pattern_from_png
{
	my( $class, $data, %opts ) = @_;

	return $class->get_class->pattern_from_png( $data, %opts );
}

=item $r->point( $color, $size, $x, $y, $angle, $shape )

Draw a point at $x,$y of $shape. Shape is one of circle, donut, triangle, upsidedownTriangle, square, hollowSquare, fatPlus or chevron.

=cut

sub point
{
	my( $self, $color, $size, $x, $y, $angle, $shape ) = @_;

	my $line_size = $size / 6;
	$line_size = $line_size > 0 ? 1 : -1 if abs($line_size) < 1.0;

	if( $shape eq "circle" )
	{
		$size -= $line_size/2;
		$self->filled_arc( $color, -1, $x, $y, $size, $size, 0, 2*pi );
	}
	elsif( $shape eq "donut" )
	{
		$size -= $line_size/2;
		$self->arc( $color, -1 * $line_size, $x, $y, $size, $size, 0, 2*pi );
	}
	elsif( $shape eq "square" )
	{
		$size /= 2;
		my @points = (
			[$x - $size, $y - $size],
			[$x + $size, $y - $size],
			[$x + $size, $y + $size],
			[$x - $size, $y + $size],
		);
		_rotate( $x, $y, $angle, \@points );
		$self->filled_polygon( $color, 0, \@points );
	}
	elsif( $shape eq "hollowSquare" )
	{
		$size /= 2;
		$size -= $line_size/2;
		my @points = (
			[$x - $size, $y - $size],
			[$x + $size, $y - $size],
			[$x + $size, $y + $size],
			[$x - $size, $y + $size],
		);
		_rotate( $x, $y, $angle, \@points );
		$self->polygon( $color, $line_size, \@points );
	}
	elsif( $shape eq "triangle" )
	{
		$size -= $line_size/2;
		my @points = (
			[$x, $y - $size/2],
			[$x - $size/2, $y + $size/2],
			[$x + $size/2, $y + $size/2],
		);
		_rotate( $x, $y, $angle, \@points );
		$self->filled_polygon( $color, -1, \@points );
	}
	elsif( $shape eq "upsidedownTriangle" )
	{
		return $self->point ($color, $size, $x, $y, $angle+pi, "triangle");
	}
	elsif( $shape eq "fatPlus" )
	{
		$size /= 2;
		my @points = (
			[$x, $y - $size], [$x, $y + $size],
			[$x - $size, $y], [$x + $size, $y],
		);
		_rotate ($x, $y, $angle, \@points);
		$self->line( $color, $line_size, map { @$_ } @points[0,1] );
		$self->line( $color, $line_size, map { @$_ } @points[2,3] );
	}
	elsif( $shape eq "chevron" )
	{
		$size /= 2;
		my @points = (
			[$x - $size, $y - $size], [$x, $y], [$x + $size, $y - $size],
		);
		_rotate ($x, $y, $angle, \@points);
		$self->continuous( $color, $line_size, [ @points[0..2] ] );
	}
	else
	{
		Carp::croak "Unrecognised point shape '$shape'";
	}
}

# utility method to rotate $points around the origin $x,$y by $angle radians
sub _rotate
{
	my( $x, $y, $angle, $points ) = @_;

	for(@$points) {
		$_->[0] -= $x;
		$_->[1] -= $y;
		my( $dx, $dy ) = @$_;
		$_->[0] = $dx*cos($angle) - $dy*sin($angle);
		$_->[1] = $dx*sin($angle) + $dy*cos($angle);
		$_->[0] += $x;
		$_->[1] += $y;
	}

	return $points;
}

=item $r->polygon( $color, $thickness, $points )

Draw a polygon along $points, including a line from the last point to the first.

=cut

sub polygon($$$$)
{
	my( $self, $color, $thickness, $points ) = @_;
}

=item $r->rectangle( $color, $thickness, $x, $y, $x2, $y2 )

Draw a rectangle between ($x,$y) and ($x2,$y2).

=cut

sub rectangle($$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $x2, $y2 ) = @_;
}

=item $r->reset_clip()

Remove the current clipping region.

=cut

sub reset_clip
{
	my( $self ) = @_;
}

=item $r->segment( $color, $font, $thickness, $x, $y, $w, $h, $s, $e )

Draw a segment whose origin is $x,$y of dimensions $w,$h starting at $s clockwise to $e (in radians).

=cut

sub segment
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e ) = @_;
}

=item $r->string( $color, $font, $size, $x, $y, $angle, $string )

Draw text consisting of $string starting at ($x,$y).

=cut

sub string($$$$$$$$)
{
	my( $self, $color, $font, $size, $x, $y, $angle, $string ) = @_;
}

=item ($w, $h) = $r->string_bounds( $font, $size, $string )

Return the bounding box (width x height) that $string will use when rendered in $font family and $size points. Does not include space used below the base line.

=cut

sub string_bounds($$$$)
{
	my( $self, $font, $size, $string ) = @_;
}

1;
