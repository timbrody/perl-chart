package Chart::Render::Cairo;

use Chart::Render;
@ISA = qw( Chart::Render );

use Cairo;
use Math::Trig;

my @CAIRO_FORMATS = ();

push @CAIRO_FORMATS, "svg" if Cairo::HAS_SVG_SURFACE;
push @CAIRO_FORMATS, "png" if Cairo::HAS_PNG_FUNCTIONS;

use strict;

use constant {
	GC_FONT_SLANT_NORMAL => 'normal',
	GC_FONT_SLANT_ITALIC => 'italic',
	GC_FONT_SLANT_OBLIQUE => 'oblique',
	GC_FONT_WEIGHT_NORMAL => 'normal',
	GC_FONT_WEIGHT_BOLD => 'bold',
};

=head1 NAME

B<Chart::Render::Cairo> - rendering surface for Cairo

=head1 METHODS

=over 4

=cut

sub available_formats { @CAIRO_FORMATS }

sub new
{
	my( $class, $format, $w, $h ) = @_;

	return $class->new_svg( $w, $h ) if( $format eq "svg" );
	return $class->new_png( $w, $h ) if( $format eq "png" );

	Carp::croak "Format '$format' is not supported";
}

sub new_svg
{
	my( $class, $w, $h ) = @_;

	my $self = bless { format => "svg" }, $class;

	$self->{_svg_data} = "";
	$self->{surface} = Cairo::SvgSurface->create_for_stream(
		sub { $self->{_svg_data} .= $_[1] },
		'',
		$w,
		$h );

	$self->{ctx} = Cairo::Context->create( $self->{surface} );

	return $self;
}

sub new_png
{
	my( $class, $w, $h ) = @_;

	my $self = bless { format => "png" }, $class;

	$self->{surface} = Cairo::ImageSurface->create( "argb32", $w, $h );

	$self->{ctx} = Cairo::Context->create( $self->{surface} );

	return $self;
}

sub _ops
{
	my( $self, $ops ) = @_;

	my $ctx = $self->{ctx};
	$ctx->save();
	if( defined $self->{_clip} )
	{
		$ctx->rectangle( @{$self->{_clip}} );
		$ctx->clip();
	}
	for(my $i = 0; $i < @$ops; $i+=2)
	{
		my( $f, $params ) = @$ops[$i,$i+1];
Carp::confess "Not an array ref" if ref($params) ne "ARRAY";
		$ctx->$f( @$params );
	}
	$ctx->restore();
}

sub _line
{
	my( $self, $thickness ) = @_;

	return (
		($thickness < 0 ? (set_antialias => ['default']) : (set_antialias => ['none'])),
		set_line_width => [abs($thickness)],
	);
}

sub _color
{
	my( $self, $color ) = @_;

	if( !defined $color or ref($color) ne "ARRAY" )
	{
		Carp::croak "Color undefined or not an array reference";
	}

	my @color = map { $_ / 255 } @$color;

	return scalar(@$color) == 3 ? (set_source_rgb => \@color) : (set_source_rgba => \@color);
}

sub _stroke
{
	my( $self, $ops ) = @_;

	push @$ops, stroke => [];

	$self->_ops( $ops );

	splice(@$ops,-2);
}

sub _fill
{
	my( $self, $ops ) = @_;

	push @$ops, fill => [];

	$self->_ops( $ops );

	splice(@$ops,-2);
}

sub render
{
	my( $self ) = @_;

	my $f = $self->{format};

	return $self->$f;
}

sub svg
{
	my( $self ) = @_;

	$self->{surface}->finish;

	if( !length $self->{_svg_data} )
	{
		Carp::confess "No data available";
	}

	return $self->{_svg_data};
}

sub png
{
	my( $self ) = @_;

	use bytes;

	my $buffer = "";
	$self->{surface}->write_to_png_stream(sub { $buffer .= $_[1] }, "");

	return $buffer;
}

=back

=head2 Drawing Methods

=over 4

=cut

# need to use a transform to make an arc with cairo
sub _arc
{
	my( $self, $x, $y, $w, $h, $s, $e, $new_path ) = @_;

	return (
		save => [],
		translate => [$x - .5, $y],
		scale => [$w/2 - .5, $h/2],
		($new_path ? (new_sub_path => []) : ()),
		arc => [0, 0, 1, $s, $e ],
		restore => [],
	);
}

sub _arc_negative
{
	my( $self, $x, $y, $w, $h, $s, $e, $new_path ) = @_;

	return (
		save => [],
		translate => [$x - .5, $y],
		scale => [$w/2 - .5, $h/2],
		($new_path ? (new_sub_path => []) : ()),
		arc_negative => [0, 0, 1, $s, $e ],
		restore => [],
	);
}

=item $r->arc( $color, $thickness, $x, $y, $w, $h, $s, $e )

Draw an arc with centre at ($x,$y) within an elipse ($w,$h) of size starting at $s and ending at $e (in radians).

=cut

sub arc($$$$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		$self->_arc( $x, $y, $w, $h, $s, $e );

	$self->_stroke( $ops );
}

=item $r->clip( $x, $y, $x2, $y2 )

Set a rectangular clipping region between $x,$y and $x2,$y2. While this is in effect nothing can be drawn beyond this region.

=cut

sub clip
{
	my( $self, $x, $y, $x2, $y2 ) = @_;

	my $t;
	$t = $y, $y = $y2, $y2 = $t if $y2 < $y;
	$t = $x, $x = $x2, $x2 = $t if $x2 < $x;

	$self->{_clip} = [$x,$y,$x2-$x,$y2-$y];
}

=item $r->continuous( $color, $thickness, $points )

Draw a continuous line along $points.

=cut

sub continuous($$$$)
{
	my( $self, $color, $thickness, $points ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		move_to => $points->[0];
	for(@$points[1..$#$points])
	{
		push @$ops, line_to => $_;
	}

	$self->_stroke( $ops );
}

=item $r->filled_arc( $color, $thickness, $x, $y, $w, $h, $s, $e )

Draw a filled arc with centre at ($x,$y) within an elipse ($w,$h) of size starting at $s and ending at $e (in radians).

=cut

sub filled_arc($$$$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		$self->_arc( $x, $y, $w, $h, $s, $e );

	$self->_fill( $ops );
	$self->_stroke( $ops ) if $thickness != 0;
}

=item $r->filled_polygon( $color, $thickness, $points )

Draw a filled polygon along $points.

=cut

sub filled_polygon($$$$)
{
	my( $self, $color, $thickness, $points ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		move_to => $points->[0];
	for(@$points[1..$#$points])
	{
		push @$ops, line_to => $_;
	}
	push @$ops, close_path => [];

	$self->_fill( $ops );
	$self->_stroke( $ops ) if $thickness != 0;
}

=item $r->filled_rectangle( $color, $thickness, $x, $y, $x2, $y2 )

Draw a filled rectangle between ($x,$y) and ($x2,$y2).

=cut

sub filled_rectangle($$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $x2, $y2 ) = @_;

	my $t;
	$t = $x, $x = $x2, $x2 = $t if $x2 < $x;
	$t = $y, $y = $y2, $y2 = $t if $y2 < $y;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		rectangle => [$x,$y,$x2-$x,$y2-$y];

	$self->_fill( $ops );
	$self->_stroke( $ops ) if $thickness != 0;
}

=item $r->filled_segment( $color, $thickness, $x, $y, $w, $h, $s, $e )

Draw a filled segment whose origin is $x,$y of dimensions $w,$h starting at $s clockwise to $e (in radians).

=cut

sub filled_segment
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e, $cw, $ch ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		move_to => [$x,$y],
		$self->_arc( $x, $y, $w, $h, $s, $e, 1 );

	if( !defined $cw || !defined $ch )
	{
		push @$ops, line_to => [$x,$y];
	}
	else
	{
		push @$ops,
			$self->_arc_negative( $x, $y, $cw, $ch, $e, $s );
	}

	push @$ops, close_path => [];

	$self->_fill( $ops );
	$self->_stroke( $ops ) if $thickness != 0;
}

=item $r->line( $color, $thickness, $x, $y, $x2, $y2 )

Draw a line along between $x,$y and $x2,$y2.

=cut

sub line($$$$)
{
	my( $self, $color, $thickness, $x, $y, $x2, $y2 ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		move_to => [$x,$y],
		line_to => [$x2,$y2];

	$self->_stroke( $ops );
}

=item $r->polygon( $color, $thickness, $points )

Draw a polygon along $points, including a line from the last point to the first.

=cut

sub polygon($$$$)
{
	my( $self, $color, $thickness, $points ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		move_to => $points->[0];
	for(@$points[1..$#$points])
	{
		push @$ops, line_to => $_;
	}
	push @$ops, close_path => [];

	$self->_stroke( $ops );
}

=item $r->rectangle( $color, $thickness, $x, $y, $x2, $y2 )

Draw a rectangle between ($x,$y) and ($x2,$y2).

=cut

sub rectangle($$$$$$$)
{
	my( $self, $color, $thickness, $x, $y, $x2, $y2 ) = @_;

	my $t;
	$t = $x, $x = $x2, $x2 = $t if $x2 < $x;
	$t = $y, $y = $y2, $y2 = $t if $y2 < $y;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		rectangle => [$x,$y,$x2-$x,$y2-$y];

	$self->_stroke( $ops );
}

=item $r->reset_clip()

Remove the current clipping region.

=cut

sub reset_clip
{
	my( $self ) = @_;

	undef $self->{_clip};
}

=item $r->segment( $color, $font, $thickness, $x, $y, $w, $h, $s, $e )

Draw a segment whose origin is $x,$y of dimensions $w,$h starting at $s clockwise to $e (in radians).

=cut

sub segment
{
	my( $self, $color, $thickness, $x, $y, $w, $h, $s, $e, $cw, $ch ) = @_;

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		$self->_line( $thickness ),
		move_to => [$x,$y],
		$self->_arc( $x, $y, $w, $h, $s, $e, 1 );

	if( !defined $cw || !defined $ch )
	{
		push @$ops, line_to => [$x,$y];
	}
	else
	{
		push @$ops,
			$self->_arc_negative( $x, $y, $cw, $ch, $e, $s );
	}

	push @$ops, close_path => [];

	$self->_stroke( $ops );
}

=item $r->string( $color, $font, $size, $x, $y, $angle, $string )

Draw text consisting of $string starting at ($x,$y).

=cut

sub string($$$$$$$$)
{
	my( $self, $color, $font, $size, $x, $y, $angle, $string ) = @_;

	utf8::upgrade( $string ) if !utf8::is_utf8( $string );

	if( !defined $font || (ref($font) && ref($font) ne "ARRAY") )
	{
		Carp::croak "font argument to string_bounds undefined or unrecognised";
	}

	if( ref($font) ne "ARRAY" )
	{
		$font = [ $font, GC_FONT_SLANT_NORMAL, GC_FONT_WEIGHT_NORMAL ];
	}

	my $ops = [];
	push @$ops,
		$self->_color( $color ),
		select_font_face => $font,
		set_font_size => [$size],
		move_to => [$x,$y],
		rotate => [$angle],
		show_text => [$string];

	$self->_ops( $ops );
}

=item ($w, $h) = $r->string_bounds( $font, $size, $string )

Return the bounding box (width x height) that $string will use when rendered in $font family and $size points. Does not include space used below the base line.

=cut

sub string_bounds($$$$)
{
	my( $self, $font, $size, $string ) = @_;

	utf8::upgrade( $string ) if !utf8::is_utf8( $string );

	if( !defined $font || (ref($font) && ref($font) ne "ARRAY") )
	{
		Carp::croak "font argument to string_bounds undefined or unrecognised";
	}

	if( ref($font) ne "ARRAY" )
	{
		$font = [ $font, GC_FONT_SLANT_NORMAL, GC_FONT_WEIGHT_NORMAL ];
	}

	my $ctx = $self->{ctx};

	$ctx->save;
	$ctx->select_font_face( @$font );
	$ctx->set_font_size( $size );
	my $extents = $ctx->text_extents( $string );
	$ctx->restore;

	return( $extents->{x_advance}, $extents->{height} );
}


1;
