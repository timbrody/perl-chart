#====================================================================
#  Chart::Composite
#
#  written by david bonner
#  dbonner@cs.bu.edu
#
#  maintained by the Chart Group
#  Chart@wettzell.ifag.de
#
#
#---------------------------------------------------------------------
# History:
#----------
# $RCSfile: Composite.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 13:25:30 $
# $Author: dassing $
# $Log: Composite.pm,v $
# Revision 1.4  2003/02/14 13:25:30  dassing
# Circumvent division of zeros
#
#====================================================================

package Chart::Composite;

use Chart::Base 3.0;
use Chart::Debug qw( trace );

@ISA = qw(Chart::Base);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#

## have to override set, so we can pass the options to the 
## sub-objects later
sub set {
  my $self = shift;
  my %opts = @_;

  $self->SUPER::set(%opts);
  
  # store the options they gave us to pass onto subs
  while(my( $key, $value ) = each %opts)
  {
	  $self->{'opts'}->{$key} = $value;
  }

  # now return
  return;
}


##  get the information to turn the chart into an imagemap
##  had to override it to reassemble the @data array correctly
sub imagemap_dump {
  my $self = shift;
  my ($i, $j);
  my @map;
  my $dataset_count = 0;
 
  # Carp::croak if they didn't ask me to remember the data, or if they're asking
  # for the data before I generate it
  unless ($self->{'imagemap'} && $self->{'imagemap_data'}) {
    Carp::croak "You need to set the imagemap option to true, and then call the png method, before you can get the imagemap data";
  }

  #make a copy of the imagemap data
  #this is the data of the first component
  for $i (1..$#{$self->{'sub_0'}->{'imagemap_data'}}) {
    for $j (0..$#{$self->{'sub_0'}->{'imagemap_data'}->[$i]}-1) {
       $map[$i][$j] = \@{$self->{'sub_0'}->{'imagemap_data'}->[$i][$j]} ;
    }
    $dataset_count++;
  }
  #and add the data of the second component
  for $i (1..$#{$self->{'sub_1'}->{'imagemap_data'}}) {
    for $j (0..$#{$self->{'sub_1'}->{'imagemap_data'}->[$i]}-1) {
      $map[$i+$dataset_count][$j] = \@{$self->{'sub_1'}->{'imagemap_data'}->[$i][$j]} ;
    }
  }
  

  # return their copy
  return \@map;

}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

##  make sure the data isn't really weird
##  and collect some basic info about it
sub _check_data {
  my $self = shift;
  my $length = 0;
  my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );

  # first things first, make sure we got the composite_info
  unless (($self->{'composite_info'}) && ($#{$self->{'composite_info'}} == 1)) {
    Carp::croak "Chart::Composite needs to be told what kind of components to use";
  }

  # make sure we don't end up dividing by zero if they ask for
  # just one y_tick
  if ($self->{'y_ticks'} == 1) {
    $self->{'y_ticks'} = 2;
    Carp::carp "The number of y_ticks displayed must be at least 2";
  }

  # remember the number of datasets
  $self->{'num_datasets'} = $#{$self->{'dataref'}};

  # remember the number of points in the largest dataset
  $self->{'num_datapoints'} = 0;
  for (0..$self->{'num_datasets'}) {
    if (scalar(@{$self->{'dataref'}[$_]}) > $self->{'num_datapoints'}) {
      $self->{'num_datapoints'} = scalar(@{$self->{'dataref'}[$_]});
    }
  }

  # find the longest x-tick label
  $self->{'x_tick_label_width'} = 1;
  $self->{'x_tick_label_height'} = 1;
  for (@{$self->{'dataref'}->[0]}) {
        next if !defined($_);
		my ($w,$h) = $self->string_bounds($font,$fsize,$self->{f_x_tick}->($_));
        $self->{'x_tick_label_width'} = $w if $w > $self->{'x_tick_label_width'};
        $self->{'x_tick_label_height'} = $h if $h > $self->{'x_tick_label_height'};
  }

  # now split the data into sub-objects
  $self->_split_data;

  return;
}


## create sub-objects for each type, store the appropriate
## data sets in each one, and stick the correct values into
## them (ie. 'gd_obj');
sub _split_data {
  my $self = shift;
  my @types = ($self->{'composite_info'}[0][0],$self->{'composite_info'}[1][0]);
  my ($i, $j);

  # load the individual modules
  require "Chart/".$types[0].".pm";
  require "Chart/".$types[1].".pm"; 

  # create the sub-objects
  $self->{'sub_0'} = ("Chart::".$types[0])->new();
  $self->{'sub_1'} = ("Chart::".$types[1])->new();

  # copy the color tables FIXME Moved from sub_update, not sure why this is necessary?
  # $sub0->{'color_table'} = { %{$self->{'color_table'}} };
  # $sub1->{'color_table'} = { %{$self->{'color_table'}} };

  # set the options (set the min_val, max_val, and y_ticks
  # options intelligently so that the sub-objects don't get
  # confused)
  $self->{'sub_0'}->set (%{$self->{'opts'}});
  $self->{'sub_1'}->set (%{$self->{'opts'}});
	# these settings are specified as e.g. min_val1, which means min_val for
	# sub-graph 1
  foreach my $opt (qw( min_val max_val y_ticks f_y_tick y_axis_scale ))
  {
	  if( defined $self->{opts}->{"${opt}1"} ) {
		  $self->{'sub_0'}->set( $opt => $self->{opts}->{"${opt}1"} );
	  }
	  if( defined $self->{opts}->{"${opt}2"} ) {
		  $self->{'sub_1'}->set( $opt => $self->{opts}->{"${opt}2"} );
	  }
  }

  # replace the surfaces
  $self->{'sub_0'}->{'surface'} = $self->{'surface'};
  $self->{'sub_1'}->{'surface'} = $self->{'surface'};

  # let the sub-objects know they're sub-objects
  $self->{'sub_0'}->{'component'} = TRUE;
  $self->{'sub_1'}->{'component'} = TRUE;

  # give each sub-object its data
  $self->{'component_datasets'} = [];
  for $i (0..1) {
	  my $sub = $self->{"sub_$i"};
	  my @ref = ($self->{'dataref'}[0]); # x-axis
		  $self->{'component_datasets'}[$i] = $self->{'composite_info'}[$i][1];
	  my $k = 0;
	  for $j (@{$self->{'composite_info'}[$i][1]}) {
		  if( !defined $self->{'dataref'}[$j] )
		  {
			  Carp::croak "composite_info refers to non-existent dataset $j (".(@{$self->{'dataref'}}-1)." datasets defined)";
		  }
# dataset colors
		  $sub->{'color_table'}{'dataset'.$k} = $self->{'color_table'}{'dataset'.($j-1)};
# neg_dataset colors
		  if( $self->{'colors'}{'neg_dataset'.($j-1)} ) {
			  $sub->{'color_table'}{'neg_dataset'.$k} = $self->{'color_table'}{'neg_dataset'.($j-1)};
		  }
# series_label
		  $sub->{'series_label'}[$k] = $self->{'series_label'}[$j-1];
# point style
		  $sub->{'pointStyle'.($k+1)} = $self->{'pointStyle'.$j};
# data
		  push @ref, $self->{'dataref'}[$j];
		  $k++;
	  }
	  $sub->_copy_data (\@ref);
  }

  # and let them check it
  $self->{'sub_0'}->_check_data;
  $self->{'sub_1'}->_check_data;

  # realign the y-axes if they want
  if ($self->{'same_y_axes'}) {
    if ($self->{'sub_0'}{'min_val'} < $self->{'sub_1'}{'min_val'}) {
      $self->{'sub_1'}{'min_val'} = $self->{'sub_0'}{'min_val'};
    }
    else {
      $self->{'sub_0'}{'min_val'} = $self->{'sub_1'}{'min_val'};
    }

    if ($self->{'sub_0'}{'max_val'} > $self->{'sub_1'}{'max_val'}) {
      $self->{'sub_1'}{'max_val'} = $self->{'sub_0'}{'max_val'};
    }
    else {
      $self->{'sub_0'}{'max_val'} = $self->{'sub_1'}{'max_val'};
    }

    $self->{'sub_0'}->_check_data;
    $self->{'sub_1'}->_check_data;
  }
	
  # find out how big the y-tick labels will be from sub_0 and sub_1
  #$self->{'y_tick_label_length1'} = $self->{'sub_0'}->{'y_tick_label_length'};
  #$self->{'y_tick_label_length2'} = $self->{'sub_1'}->{'y_tick_label_length'};

  # now return
  return;
}

sub _draw_legend {
  my $self = shift;
  my ($length,$height);
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );

  # check to see if they have as many labels as datasets,
  # warn them if not
  if (($#{$self->{'legend_labels'}} >= 0) &&
       ((scalar(@{$self->{'legend_labels'}})) != $self->{'num_datasets'})) {
    Carp::carp "The number of legend labels and datasets doesn\'t match";
  }
 
  # init a field to store the length of the longest legend label
  unless ($self->{'max_legend_label_width'}) {
	$self->{'max_legend_label_width'} = 0;
    $self->{'max_legend_label_height'} = 0;
  }
 
  # fill in the legend labels, find the longest one
  for (1..$self->{'num_datasets'}) {
    unless ($self->{'legend_labels'}[$_-1]) {
      $self->{'legend_labels'}[$_-1] = "Dataset $_";
    }
    #$length = length($self->{'legend_labels'}[$_-1]);
    ($length,$height) = $self->string_bounds($font,$fsize,$self->{'legend_labels'}[$_-1]);
    if ($length > $self->{'max_legend_label_width'}) {
      $self->{'max_legend_label_width'} = $length;
      $self->{'max_legend_label_height'} = $height;
    }
  }

  # copy the current boundaries and colors into the sub-objects
  $self->_sub_update(); 
  # init the legend example height
  $self->_legend_example_height_init;

  # modify the dataset color table entries to avoid duplicating
  # dataset colors.
#  my ($n0, $n1) = map { scalar @{ $self->{'composite_info'}[$_][1] } } 0..1;
#  for (0..$n1-1) {
#    $self->{'sub_1'}{'color_table'}{'dataset'.$_} 
#      = $self->{'color_table'}{'dataset'.($_+$n0)};
#  }

  my $x1 = $self->{'curr_x_min'} + $self->{'graph_border'}
			+ $self->{'sub_0'}->{'y_tick_label_width'}
	  		+ $self->{'tick_len'} + (3 * $self->{'text_space'});
  my $x2 = $self->{'curr_x_max'} - $self->{'graph_border'}
			- $self->{'sub_1'}->{'y_tick_label_width'}
			- $self->{'tick_len'} - (3 * $self->{'text_space'});
  if ($self->{'y_label'}) {
	$x1 += $self->{'max_legend_label_height'} + 2 * $self->{'text_space'};
  }
  if ($self->{'y_label2'}) {
    $x2 -= $self->{'max_legend_label_height'} + 2 * $self->{'text_space'};
  }

  # different legend types
  if ($self->{'legend'} eq 'bottom') {
    $self->_draw_bottom_legend($x1,$x2);
  }
  elsif ($self->{'legend'} eq 'right') {
    $self->_draw_right_legend;
  }
  elsif ($self->{'legend'} eq 'left') {
    $self->_draw_left_legend;
  }
  elsif ($self->{'legend'} eq 'top') {
    $self->_draw_top_legend($x1,$x2);
  }
  elsif ($self->{'legend'} eq 'none') {
    # $self->_draw_none_legend;
  } else {
    Carp::carp "I can't put a legend there\n";
  }
 
  # and return
  return 1;
}

## draw the ticks and tick labels
sub _draw_ticks {
  my $self = shift;

  # draw the x ticks
  $self->_draw_x_ticks;

  # update the boundaries in the sub-objects
  $self->_boundary_update ($self, $self->{'sub_0'});
  $self->_boundary_update ($self, $self->{'sub_1'}); 

  # now the y ticks
  $self->_draw_y_ticks;

  # then return
  return;
}


## draw the x-ticks and their labels
sub _draw_x_ticks {
  my $self = shift;

  my $data = $self->{'dataref'};

  my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
  my ($x1, $x2, $y1, $y2);
  my ($width, $delta);

  $self->{'grid_data'}->{'x'} = [];

  # allow for the amount of space the y-ticks will push the
  # axes over to the right and to the left
## _draw_y_ticks allows 3 * text_space, not 2 * ;  this caused mismatch between
## the ticks (and grid lines) and the data.
#   $x1 = $self->{'curr_x_min'} + ($w * $self->{'y_tick_label_length1'})
#          + (2 * $self->{'text_space'}) + $self->{'tick_len'};
#   $x2 = $self->{'curr_x_max'} - ($w * $self->{'y_tick_label_length2'})
#          - (2 * $self->{'text_space'}) - $self->{'tick_len'};
  $x1 = $self->{'curr_x_min'} + $self->{'sub_0'}->{'y_tick_label_width'}
         + (3 * $self->{'text_space'}) + $self->{'tick_len'};
  $x2 = $self->{'curr_x_max'} - $self->{'sub_1'}->{'y_tick_label_width'}
         - (3 * $self->{'text_space'}) - $self->{'tick_len'};
  $y1 = $self->{'curr_y_max'} - $self->{'text_space'};

  # get the delta value, figure out how to draw the labels
  $width = $x2 - $x1;
  $delta = $width / ( $self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1 );

	$self->_draw_x_ticks_actual( $x1, $y1, $width );
}


## draw the y-ticks and their labels
sub _draw_y_ticks {
  my $self = shift;

  # let the first guy do his
  $self->{'sub_0'}->_draw_y_ticks ('left');

  # and update the other two objects
  $self->_boundary_update ($self->{'sub_0'}, $self);
  $self->_boundary_update ($self->{'sub_0'}, $self->{'sub_1'});

  # now draw the other ones
  $self->{'sub_1'}->_draw_y_ticks ('right');

  # and update the other two objects
  $self->_boundary_update ($self->{'sub_1'}, $self);
  $self->_boundary_update ($self->{'sub_1'}, $self->{'sub_0'});

  # then return
  return;
}


## finally get around to plotting the data
sub _draw_data {
  my $self = shift;

  # do a grey background if they want it
  if ($self->{'grey_background'}) {
    $self->_grey_background;
    $self->{'sub_0'}->{'grey_background'} = FALSE;
    $self->{'sub_1'}->{'grey_background'} = FALSE;
  }

  # draw grid again if necessary (if grey background ruined it..)
  unless ($self->{grey_background}) {
    $self->_draw_grid_lines if $self->{grid_lines};
    $self->_draw_x_grid_lines if $self->{x_grid_lines};
    $self->_draw_y_grid_lines if $self->{y_grid_lines};
    $self->_draw_y2_grid_lines if $self->{y2_grid_lines};
  }


  # do a final bounds update
  $self->_boundary_update ($self, $self->{'sub_0'});
  $self->_boundary_update ($self, $self->{'sub_1'});
  

  # init the imagemap data field if they wanted it
  if ($self->{'imagemap'}) {
    $self->{'imagemap_data'} = [];
  }

  # now let the component modules go to work
  
  $self->{'sub_0'}->_draw_data;
  $self->{'sub_1'}->_draw_data;
      
  return;
}


## update all the necessary information in the sub-objects
sub _sub_update {
  my $self = shift;
  my $sub0 = $self->{'sub_0'};
  my $sub1 = $self->{'sub_1'};

  # update the boundaries
  $self->_boundary_update ($self, $sub0);
  $self->_boundary_update ($self, $sub1);

  # now return
  return;
}


## copy the current gd_obj boundaries from one object to another
sub _boundary_update {
  my $self = shift;
  my $from = shift;
  my $to = shift;

  $to->{'curr_x_min'} = $from->{'curr_x_min'};
  $to->{'curr_x_max'} = $from->{'curr_x_max'};
  $to->{'curr_y_min'} = $from->{'curr_y_min'};
  $to->{'curr_y_max'} = $from->{'curr_y_max'};

  return;
}

sub _draw_y_grid_lines {
	my ($self) = shift;
	$self->{'sub_0'}->_draw_y_grid_lines();
	return;
}

sub _draw_y2_grid_lines {
	my ($self) = shift;
	$self->{'sub_1'}->_draw_y2_grid_lines();
	return;
}


# init the legend_example_height_values
sub _legend_example_height_init {
  my $self = shift;
  my $a = $self->{'num_datasets'};
  my ($b, $e) =(0,0);
  my $bis='..';
  
      
  if (!$self->{'legend_example_height'}) {
  
    for my $i (0..$a) {
    $self->{'legend_example_height'.$i} = 1;
    }
  }
 
  if ($self->{'legend_example_height'}) { 
 
   for my $i (0..$a) {
   
   if (defined($self->{'legend_example_height'.$i})) { }
   else { ($self->{'legend_example_height'.$i}) = 1;}   
  
   }

   for  $b (0..$a) {
    for  $e (0..$a) {
      my $anh = sprintf($b.$bis.$e);
       if (defined($self->{'legend_example_height'.$anh})) {
        if ($b>$e) {Carp::croak "Please reverse the datasetnumber in legend_example_height\n";}
       	  for (my $n=$b;$n<=$e;$n++) {
	    $self->{'legend_example_height'.$n} = $self->{'legend_example_height'.$anh};
	 }
        }
       }
    }
   }
 
  
  
}     

=head1 PROPERTIES

=over4

=item composite_info => [ [ Bars => [1,2] ], [ Lines => [3,4] ] ]

Specific what type of charts to use and which datasets each sub-chart renders.

=back

## be a good module and return 1
1;
