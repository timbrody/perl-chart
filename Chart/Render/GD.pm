
# Algorithm to fill an arc (not in GD library ...)
sub _gd_arc {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my($self,$x,$y,$w,$h,$s,$e,$color,$style) = @_;
	my $gd = $self->{'gd_obj'};
	$style ||= 0;

	# Sanity check
	return if $w < 0 or $h < 0;

	my $p = new GD::Polygon;

	# Make sure angles are positive and e > s
	$s += 360 while $s < 0;
	$e += 360 while $e < 0;
	$e += 360 while $e < $s;

	$s %= 360;
	$e %= 360 if $e > 360;

	# In the algorithm we need to use the radius
	$w /= 2;
	$h /= 2;

	$s = deg2rad($s);
	$e = $e == 360 ? pi*2 : deg2rad($e); # Otherwise $e goes to zero at 360

	$p->addPt($x,$y);
	my $inc = atan(1/$w); # degrees for .5 pixel difference
	for(my $a = $s; $a <= $e; $a+=$inc){
		$p->addPt($x + cos($a) * $w, $y + sin($a) * $h);
	}

	if( $style & GD_ARC_FILLED )
	{
		$gd->filledPolygon($p,$color);
	}
	else
	{
		$gd->polygon($p,$color);
	}
}

# Utility functions to set the correct line thickness before
# we draw lines (i.e. so the user can easily create
# a higher res chart)
sub _gd_line {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my $self = shift;
	$self->{'gd_obj'}->setThickness($self->{'line_size'});
	$self->{'gd_obj'}->line(@_);
	$self->{'gd_obj'}->setThickness(1);
}

sub _gd_line_aa {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my $self = shift;
	$self->{'gd_obj'}->setAntiAliased(pop @_);
	$self->{'gd_obj'}->line(@_, GD::gdAntiAliased);
}

sub _gd_rectangle {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my $self = shift;
	return if defined $_[5] && $_[5] == 0;
	$self->{'gd_obj'}->setThickness(defined $_[5] ? $_[5] : $self->{'line_size'});
	$self->{'gd_obj'}->rectangle(@_[0..4]);
	$self->{'gd_obj'}->setThickness(1);
}

sub _gd_string($$$$$$$) {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my ($self,$color,$field,$angle,$x,$y,$string) = @_;
	my ($font,$size) = (
		$self->{$field},
		$self->{$field.'_size'},
		);
	unless( $font ) {
		croak ref($self)."::_gd_string) font undefined / field ('$field') is not a valid font.";
	}
	unless( ref($font) eq 'GD::Font' || -e $font ) {
		croak ref($self)."::_gd_string) $field must be either a GD Font or the location of a TrueType (ttf) font.";
	}
	if( ref($font) eq 'GD::Font' ) {
		return ($angle == ANGLE_VERTICAL) ?
			$self->{'gd_obj'}->stringUp($font,$x,$y,$string,$color) :
			$self->{'gd_obj'}->string($font,$x,$y,$string,$color);
	} else {
		# Bizarrely stringFT seems to render upwards from $y, while
		# string renders downwards from $y, so this is a hack to
		# shift TrueType rendering to the same point
		my ($w,$h,$offset) = $self->_gd_string_dimensions($field,$string);
		return $self->{'gd_obj'}->stringFT($color,$font,$size,$angle,$x+sin($angle)*$h,$y+cos($angle)*$offset,$string);
	}
}

sub _gd_string_width {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my ($w,$h) = _gd_string_dimensions(@_);
	return $w || 0;
}

sub _gd_string_height {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my ($w,$h) = _gd_string_dimensions(@_);
	return $h;
}

sub _gd_string_dimensions {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
	my ($self,$field,$string) = @_;
	my ($font,$size) = (
		$self->{$field},
		$self->{$field.'_size'},
		);
	unless( defined($font) ) {
		croak ref($self)."::_gd_string_dimensions) Internal Error: $field is not a defined font field.";
	}
	unless( ref($font) eq 'GD::Font' || -e $font ) {
		croak ref($self)."::_gd_string_dimensions) $field must be either a GD::Font or the location of a TrueType (ttf) font.";
	}
	if( ref($font) eq 'GD::Font' ) {
		return (length($string) * $font->width,$font->height);
	}
	my @bounds = GD::Image->stringFT(0,$font,$size,0,0,0,$string);
	return ($bounds[2],$bounds[1]-$bounds[5],-1*$bounds[5]); # Height excludes below the base line
}

sub _prepare_brush {

    my $self      = shift;
    my $color     = shift;
    my $type      = shift;
    my $typeStyle = shift;

    # decide what $type should be in the event that a param isn't
    # passed -- this is necessary to preserve backward compatibility
    # with apps that use this module prior to putting _prepare_brush
    # in with Base.pm
    if ( (! length($type) ) ||
         ( ! grep { $type eq $_ } ('line', 'point') ) ) {

        $typeStyle = $type;
        $type = 'line' if ref $self eq 'Chart::Lines';
        $type = 'point' if ref $self eq 'Chart::Points';
        # Chart::LinesPoints is expected to pass a $type param

    }

    my ($radius, @rgb, $brush, $white, $newcolor);

    # get the rgb values for the desired color
    @rgb = $self->{'gd_obj'}->rgb($color);

    # get the appropriate brush size
    if ($type eq 'line') {
        $radius = $self->{'brush_size'}/1.5;
    } elsif ($type eq 'point') {
        $radius = $self->{'pt_size'}/1.5;
    }

    # create the new image
    $brush = GD::Image->new ($radius*2, $radius*2);

    # get the colors, make the background transparent
    $white    = $brush->colorAllocate (255,255,255);
    $newcolor = $brush->colorAllocate (@rgb);
    $brush->transparent ($white);

    # draw the circle
    if ( $type eq 'line') {
        $brush->arc ($radius-1, $radius-1, $radius, $radius, 0, 360, $newcolor);
        $brush->fill ($radius-1, $radius-1, $newcolor);

        # RLD
        #
        # Does $brush->fill really have to be here?  Dunno... this
        # seems to be a relic from earlier code
        #
        # Note that 'line's don't benefit from a $typeStyle... yet.
        # It shouldn't be too tough to hack this in by taking advantage
        # of GD's gdStyled facility

    }

    if ( $type eq 'point' ) {
		$typeStyle = 'default' if(
			!defined($typeStyle) ||
			$typeStyle !~ /^circle|donut|triangle|upsidedownTriangle|square|hollowSquare|fatPlus$/
		);

        my ($xc, $yc) = ($radius-1, $radius-1);

        # Note that 'default' will produce the same effect
        # as a 'circle' typeStyle
        if ( grep { $typeStyle eq $_ } ('default', 'circle', 'donut') ) {

            $brush->arc($xc, $yc, $radius, $radius, 0, 360, $newcolor);
            $brush->fill ($xc, $yc, $newcolor);

            # draw a white (and therefore transparent) circle in the middle
            # of the existing circle to make the "donut", if appropriate

            if ( $typeStyle eq 'donut' ) {
                $brush->arc($xc, $yc, int($radius/2), int($radius/2),
                            0, 360, $white);
                $brush->fill ($xc, $yc, $white);
            }
        }

        if ( grep { $typeStyle eq $_ } ('triangle', 'upsidedownTriangle' ) ){

            my $poly = new GD::Polygon;
            my $sign = ( $typeStyle eq 'triangle' ) ? 1 : (-1);
            my $z = int (0.8 * $radius); # scaling factor

            # co-ords are chosen to make an equilateral triangle

            $poly->addPt($xc,
                         $yc - ($z * $sign));
            $poly->addPt($xc + int((sqrt(3) * $z) / 2),
                         $yc + (int($z/2) * $sign));
            $poly->addPt($xc - int((sqrt(3) * $z) / 2),
                         $yc + (int($z/2) * $sign));

            $brush->filledPolygon($poly, $newcolor);
        }

        if ( $typeStyle eq 'fatPlus' ) {

            my $poly = new GD::Polygon;

            my $z = int(0.3 * $radius);

            $poly->addPt($xc +     $z, $yc + $z);
            $poly->addPt($xc + 2 * $z, $yc + $z);
            $poly->addPt($xc + 2 * $z, $yc - $z);

            $poly->addPt($xc + $z,     $yc - $z);
            $poly->addPt($xc + $z,     $yc - 2 * $z);
            $poly->addPt($xc - $z,     $yc - 2 * $z);

            $poly->addPt($xc -     $z, $yc - $z);
            $poly->addPt($xc - 2 * $z, $yc - $z);
            $poly->addPt($xc - 2 * $z, $yc + $z);

            $poly->addPt($xc - $z,     $yc + $z);
            $poly->addPt($xc - $z,     $yc + 2 * $z);
            $poly->addPt($xc + $z,     $yc + 2 * $z);
            $brush->filledPolygon($poly, $newcolor);
        }

        if ( grep { $typeStyle eq $_ } ('square', 'hollowSquare') ) {

            my $poly = new GD::Polygon;
            my $z = int (0.5 * $radius);

            $brush->filledRectangle($xc - $z, $yc - $z,
                                    $xc + $z, $yc + $z,
                                    $newcolor);

            if ( $typeStyle eq 'hollowSquare' ) {

                $z = int($z/2);

                $brush->filledRectangle($xc - $z, $yc - $z,
                                        $xc + $z, $yc + $z,
                                        $white);
            }
        }
    }

    # set the new image as the main object's brush
    return $brush;
}
