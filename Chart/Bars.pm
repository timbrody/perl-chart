#====================================================================
#  Chart::Bars
#
#  written by david bonner
#  dbonner@cs.bu.edu
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Bars.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 13:10:05 $
# $Author: dassing $
# $Log: Bars.pm,v $
# Revision 1.4  2003/02/14 13:10:05  dassing
# Circumvent division of zeros
#
#====================================================================

package Chart::Bars;

use Chart::Base 3.0;

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

use constant DEBUG => 0;

=pod

=head1 NAME

Chart::Bars - Bar Charts

=head1 DESCRIPTION

Vertical bar chart.

=head1 SYNOPSIS

	use Chart::Bars;

	my $ch = new Chart::Bars(640,480);

	$ch->set(
		key=>value,
	);

=cut

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#


#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

sub _draw_legend_entry_example {
	my( $self, $color, $x, $y, $h, $shape ) = @_;

	my $bar_border_size = $self->{'bar_border_size'};
	$bar_border_size = $self->{'line_size'} unless defined $bar_border_size;

	my $legend_example_size = $self->{'legend_example_size'};
	my $misccolor = $self->_color_role_to_rgb('misc');

	my $x2 = $x + $legend_example_size;
	my $y2 = $y;
	$y -= $h;

	# draw a square for bars
	$self->{'surface'}->filled_rectangle($color,
			0,
			$x, $y, 
			$x2, $y2);

	$self->{'surface'}->rectangle($misccolor,
			$bar_border_size,
			$x, $y, 
			$x2, $y2);
}

## finally get around to plotting the data
sub _draw_data {
	my $self = shift;
	my( $font, $fsize ) = $self->_font_role_to_font( 'series_label' );
	my $data = $self->{'dataref'};
	my $misccolor = $self->_color_role_to_rgb('misc');
	my $white = [$self->_color_spec_to_rgb('data_label','white')];
	my $pink = [255,0,255];
	my ($width, $height, $delta1, $delta2, $map, $mod, $cut);
	my ($label, @LABELS, $i, $j, $color, $neg_color);
	my $zero_offset = $self->{'zero_offset'} || [];
	if( ref($zero_offset) eq 'ARRAY' ) {
		for(1..$self->{'num_datasets'}) {
			$zero_offset->[$_-1] ||= 0;
		}
	} else {
		$zero_offset = [$zero_offset];
		for(2..$self->{'num_datasets'}) {
			$zero_offset->[$_-1] = $zero_offset->[0];
		}
	}

	my $bar_border_size = $self->{'bar_border_size'};
	$bar_border_size = $self->{'line_size'} unless defined $bar_border_size;

# init the imagemap data field if they wanted it
	if ($self->{'imagemap'}) {
		$self->{'imagemap_data'} = [];
	}

# find both delta values ($delta1 for stepping between different
# datapoint names, $delta2 for stepping between datasets for that
# point) and the mapping constant
	$width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
	$height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
	my $delta = $width / ($self->{num_datapoints} || 1);

	my $d_width = $self->{max_val} - $self->{min_val};
	$d_width = log($d_width) if $self->{y_axis_scale} eq 'logarithmic';

	my $bar_width = $delta / (($self->{spaced_bars} ? $self->{num_datasets} + 2 : $self->{num_datasets}) || 1);
	$bar_width = 1 if $bar_width <= 1.0;

# draw the bars
	for $i (1..$self->{'num_datasets'}) {   

# get the color for this dataset
		$color = $self->_color_role_to_rgb('dataset'.($i-1));
		$neg_color = defined($self->{'color_table'}{'neg_dataset'.($i-1)}) ?
			$self->_color_role_to_rgb('neg_dataset'.($i-1)) :
				$color;

		my $label_style = $self->{'series_label'.($i-1)};

# draw every bar for this dataset
		for $j (0..$self->{'num_datapoints'}) {
			my $value = $data->[$i][$j];

# don't try to draw anything if there's no data
			if (!defined $value ) {
				if ($self->{'imagemap'}) {
					$self->{'imagemap_data'}->[$i][$j] = [undef(), undef(), undef(), undef()];
				}
				next;
			}

			my $direction = $value >= $zero_offset->[$i-1] ? 1 : -1;

			my( $w, $h );
			if( defined $label_style ) {
				$label = $self->{'f_y_tick'}->($value - $zero_offset->[$i-1]);
				($w,$h) = $self->{'surface'}->string_bounds($font,$fsize,$label);
			}

#cut the bars off, if needed
			my $cut = FALSE;
			if ($value > $self->{max_val}) {
				$value = $self->{max_val};
				$cut = TRUE;
			}
			elsif( $value < $self->{min_val} ) {
				$value = $self->{min_val};
				$cut = TRUE;
			}

			# center of all bars
			my $x1 = $self->{curr_x_min} + $j * $delta + $delta / 2;

			# left-coord of this bar
			$x1 -= $self->{num_datasets} * $bar_width / 2;
			$x1 += ($i-1) * $bar_width;

			# right-coord of this bar
			my $x2 = $x1 + $bar_width;

			# end of bar
			my $y1;
			# start of bar
			my $y2;
			if( $self->{y_axis_scale} eq 'logarithmic' ) {
				next if $value == 0; # log(0)
				$y1 = $self->{curr_y_max} - $height * log($value) / $d_width;
				$y2 = $self->{curr_y_max}; # offset logarithmic axis?
			}
			else {
				$y1 = $self->{curr_y_max} - $height * ($value-$self->{min_val}) / $d_width;
				if( $self->{min_val} < 0 ) {
					$y2 = $self->{curr_y_max} - $height * ($zero_offset->[$i-1]-$self->{min_val}) / $d_width;
				}
				else {
					$y2 = $self->{curr_y_max} - $height * $zero_offset->[$i-1] / $d_width;
				}
			}


			if ($self->{'imagemap'}) {
				$self->{'imagemap_data'}->[$i][$j] = [$x1, $y1, $x2, $y2];
			}

# draw the bar
			my $c = $direction == 1 ? $color : $neg_color;
			if( defined( $self->{'f_bar_color'} ) ) {
				$c = &{$self->{'f_bar_color'}}($data->[$i][$j], $c);
			}
			$self->{surface}->filled_rectangle( $c, 0,
				$x1, $y1,
				$x2, $y2
			);

			if( defined $label_style ) {
				my $y = $y1 + $direction*($w+$self->{text_space});
				if(
					$label_style eq 'vertical' &&
					$y < $self->{curr_y_max} &&
					$y > $self->{curr_x_min}
				  ) {
					push @LABELS, [
						$white, $font, $fsize,
						($x1+$x2)/2 - $h/2, $y, ANGLE_VERTICAL,
						$label
					];
				}
				else {
					push @LABELS, [
						$color, $font, $fsize,
						($x1+$x2)/2 - $w/2, $y1 - $direction*$self->{text_space}, 0,
						$label
					];
				}
			}

# now outline it. outline red if the bar had been cut off
			if( $cut )
			{
				$self->{'surface'}->rectangle($pink, $bar_border_size, $x1, $y1, $x2, $y2);
# Line through the bar to indicate it's been cut off
				my $line_size = int($bar_width/3) || 1;
				$self->{'surface'}->line($white, $line_size,
					$x1, ($y1+$y2)/2,
					$x1, ($y1+$y2)/2+$bar_width
				);
				$self->{'surface'}->line($white, $line_size,
					$x1, ($y1+$y2)/2+$bar_width,
					$x1, ($y1+$y2)/2+2*$bar_width
				);
			}
			else
			{
				$self->{'surface'}->rectangle($misccolor, $bar_border_size, $x1, $y1, $x2, $y2);
			}
		}
	}

# render the series labels after columns, otherwise the text gets overwritten
	for(@LABELS) {
		$self->{'surface'}->string(@$_);
	}

# and finally box it off 
	$self->{'surface'}->rectangle(
			$misccolor,
			1,
			$self->{'curr_x_min'},
			$self->{'curr_y_min'},
			$self->{'curr_x_max'},
			$self->{'curr_y_max'});
}

## be a good module and return 1
1;
