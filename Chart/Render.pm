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

=item $r->point( $color, $size, $x, $y, $shape )

Draw a point at $x,$y of $shape. Shape is one of circle, donut, triangle, upsidedownTriangle, square, hollowSquare or fatPlus.

=cut

sub point
{
	my( $self, $color, $size, $x, $y, $shape ) = @_;

	my $line_size = $size / 6;
	$line_size = 1 if $line_size < 1.0;

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
		my $x1 = $x - $size/2;
		my $y1 = $y - $size/2;
		my $x2 = $x + $size/2;
		my $y2 = $y + $size/2;
		$self->filled_rectangle( $color, 0, $x1, $y1, $x2, $y2 );
	}
	elsif( $shape eq "hollowSquare" )
	{
		my $x1 = $x - $size/2 + $line_size/2;
		my $y1 = $y - $size/2 + $line_size/2;
		my $x2 = $x + $size/2 - $line_size/2;
		my $y2 = $y + $size/2 - $line_size/2;
		$self->rectangle( $color, $line_size, $x1, $y1, $x2, $y2 );
	}
	elsif( $shape eq "triangle" )
	{
		$size -= $line_size/2;
		my @points = (
			[$x, $y - $size/2],
			[$x - $size/2, $y + $size/2],
			[$x + $size/2, $y + $size/2],
		);

		$self->filled_polygon( $color, -1, \@points );
	}
	elsif( $shape eq "upsidedownTriangle" )
	{
		$size -= $line_size/2;
		my @points = (
			[$x, $y + $size/2],
			[$x + $size/2, $y - $size/2],
			[$x - $size/2, $y - $size/2],
		);

		$self->filled_polygon( $color, -1, \@points );
	}
	elsif( $shape eq "fatPlus" )
	{
		$self->line( $color, $line_size, $x, $y - $size/2, $x, $y + $size/2 );
		$self->line( $color, $line_size, $x - $size/2, $y, $x + $size/2, $y );
	}
	else
	{
		Carp::croak "Unrecognised point shape '$shape'";
	}
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
