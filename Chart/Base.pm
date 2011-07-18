package Chart::Base;

=head1 NAME

Chart::Base 

=head1 AUTHOR

david bonner <dbonner@cs.bu.edu>

Maintained by the Chart Group
Chart@wettzell.ifag.de

2.4 by Tim Brody <tdb01r@ecs.soton.ac.uk>

=head1 HISTORY

$RCSfile: Base.pm,v $ $Revision: 1.8 $ $Date: 2003/04/08 16:03:41 $
$Author: dassing $
$Log: Base.pm,v $
Revision 1.8  2003/04/08 16:03:41  dassing
_draw_y_grid_lines does plot all lines now

 Revision 1.7  2003/03/20 15:01:11  dassing
 Some print statements did not go to STDERR

 Revision 1.6  2003/01/14 13:38:37  dassing
 Big changes for Version 2.0

 Revision 1.5  2002/06/19 12:36:58  dassing
 Correcting some undefines

 Revision 1.4  2002/06/06 07:38:25  dassing
 Updates in Function _find_y_scale by David Pottage

 Revision 1.3  2002/05/31 13:18:02  dassing
 Release 1.1

 Revision 1.2  2002/05/29 16:13:20  dassing
 Changes included by David Pottage

=cut

use Carp;
use Math::Trig;
use Exporter;

use Chart::Render qw( :ops );
use Chart::Debug qw( trace debug );
use FileHandle;

use vars qw( $VERSION @ISA @EXPORT );

$VERSION = '3.0';

@ISA = qw( Exporter );

# FIXME Vertical TT isn't correct
use constant DEBUG => 0;
use constant {
	ANGLE_VERTICAL => (270 / 360) * (2 * pi),
	TRUE => 1,
	FALSE => 0,
	GD_ARC_FILLED => 1,

	CHART_TOP => 1,
	CHART_RIGHT => 2,
	CHART_BOTTOM => 4,
	CHART_LEFT => 8,
};

@EXPORT = qw( ANGLE_VERTICAL TRUE FALSE CHART_TOP CHART_RIGHT CHART_BOTTOM CHART_LEFT );

use vars qw(%FALSEABLE %NAMED_COLORS $MAX_DATASET_COLORS);

# options that historically took 'false' as boolean FALSE
%FALSEABLE = map { $_ => 1 } qw(
	grey_background
	spaced_bars
);

%NAMED_COLORS = (
  'white'		=> [255,255,255],
  'black'		=> [0,0,0],
  'red'			=> [200,0,0],
  'green'		=> [0,175,0],
  'blue'		=> [0,0,200],
  'orange'		=> [250,125,0],
  'orange2'		=> [238,154,0],
  'orange3'		=> [205,133,0],
  'orange4'		=> [139,90,0],
  'yellow'		=> [225,225,0],
  'purple'		=> [200,0,200],
  'light_blue'		=> [0,125,250],
  'light_green'		=> [125,250,0],
  'light_purple'	=> [145,0,250],
  'pink'		=> [250,0,125],
  'peach'		=> [250,125,125],
  'olive'		=> [125,125,0],
  'plum'		=> [125,0,125],
  'turquoise'		=> [0,125,125],
  'mauve'		=> [200,125,125],
  'brown'		=> [160,80,0],
  'grey'		=> [225,225,225],
  'gray'		=> [225,225,225],
  'HotPink'             => [255,105,180],
  'PaleGreen1'          => [154,255,154],
  'PaleGreen2'          => [144,238,144],
  'PaleGreen3'          => [124,205,124],
  'PaleGreen4'          => [84,138,84],
  'DarkBlue'            => [0,0,139],
  'BlueViolet'          => [138,43,226],
  'PeachPuff'           => [255,218,185],
  'PeachPuff1'          => [255,218,185],
  'PeachPuff2'          => [238,203,173],
  'PeachPuff3'          => [205,175,149],
  'PeachPuff4'          => [139,119,101],
  'chocolate1'          => [255,127,36], 
  'chocolate2'          => [238,118,33], 
  'chocolate3'          => [205,102,29], 
  'chocolate4'          => [139,69,19],
  'LightGreen'          => [144,238,144],
  'lavender'            => [230,230,250],
  'MediumPurple'        => [147,112,219],
  'DarkOrange'          => [255,127,0],
  'DarkOrange2'         => [238,118,0],
  'DarkOrange3'         => [205,102,0],
  'DarkOrange4'         => [139,69,0],
  'SlateBlue'           => [106,90,205],
  'BlueViolet'          => [138,43,226],
  'RoyalBlue'           => [65,105,225],
);

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#

##  standard nice object creator
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};

  bless $self, $class;
  $self->_init(@_);

  return $self;
}

##  main method for customizing the chart, lets users
##  specify values for different parameters
sub set {
  my $self = shift;
  my %opts = @_;
  
  # basic error checking on the options, just warn 'em
  unless ($#_ % 2) {
    carp "Whoops, some option to be set didn't have a value.\n",
         "You might want to look at that.\n";
  }
 
  # set the options
  while(my ($key,$value) = each %opts) {
	  if ($FALSEABLE{$key} && lc($value) eq 'false') {
		  $value = FALSE;
	  }
	  elsif( $key eq 'y_axis_scale' && $value eq 'log' ) {
		  $value = 'logarithmic';
	  }
	  $self->{$key} = $value;
  }

  # if someone wants to change the grid_lines color, we should set all
  # the colors of the grid_lines
  if( exists($opts{'colors'}) && defined($opts{'colors'}->{'grid_lines'}) ) {
	$self->{'colors'}{'y_grid_lines'}
	= $self->{'colors'}{'x_grid_lines'}
	= $self->{'colors'}{'y2_grid_lines'} = $opts{'colors'}->{'grid_lines'};
  }
  
  # now return
  return 1;
}


##  Graph API
sub add_pt {
  my $self = shift;
  my @data = @_;

  # error check the data (carp, don't croak)
  if ($self->{'dataref'} && ($#{$self->{'dataref'}} != $#data)) {
    carp "New point to be added has an incorrect number of data sets";
    return 0;
  }

  # copy it into the dataref
  for (0..$#data) {
    push @{$self->{'dataref'}->[$_]}, $data[$_];
  }
  
  # now return
  return 1;
}


##  more Graph API
sub add_dataset {
  my $self = shift;
  my @data = @_;

  # error check the data (carp, don't croak)
  if ($self->{'dataref'} && ($#{$self->{'dataref'}->[0]} != $#data)) {
    carp "New data set to be added has an incorrect number of points";
  }

  # copy it into the dataref
  push @{$self->{'dataref'}}, [ @data ];
  
  # now return
  return 1;
}

# it's also possible to add a complete datafile
sub add_datafile  {
   my $self = shift;
   my $filename = shift;
   my $format = shift;
   my ($File, @array);
   
   # do some ugly checking to see if they gave me
   # a filehandle or a file name
   if ((ref \$filename) eq 'SCALAR') {
    # they gave me a file name
    open ($File, $filename) or croak "Can't open the datafile: $filename.\n";
   }
   elsif ((ref \$filename) =~ /^(?:REF|GLOB)$/) {
    # either a FileHandle object or a regular file handle
    $File = $filename;
   }
   else {
    carp "I'm not sure what kind of datafile you gave me,\n",
          "but it wasn't a filename or a filehandle.\n";
   }

   #add the data
   while(<$File>) {
      @array = split;
      if ( @array != ( )) {
        if ($format =~ m/^pt$/i) {
          $self->add_pt(@array);
        }
        elsif ($format =~ m/^set$/i) {
          $self->add_dataset(@array);
        }
        else {
          carp "Tell me what kind of file you gave me: 'pt' or 'set'\n";
        }
      }
   }
   close ($File);
}

##  even more Graph API
sub clear_data {
  my $self = shift;

  # undef the internal data reference
  $self->{'dataref'} = undef;

  # now return
  return 1;
}


##  and the last of the Graph API
sub get_data {
  my $self = shift;
  my $ref = [];
  my ($i, $j);

  # give them a copy, not a reference into the object
  for $i (0..$#{$self->{'dataref'}}) {
    @{ $ref->[$i] } = @{ $self->{'dataref'}->[$i] }
## speedup, compared to...
#   for $j (0..$#{$self->{'dataref'}->[$i]}) {
#     $ref->[$i][$j] = $self->{'dataref'}->[$i][$j];
#   }
  }

  # return it
  return $ref;
}

sub _open_fh
{
	my( $self, $file ) = @_;

	my $fh;

	# do some ugly checking to see if they gave me
	# a filehandle or a file name
	if ((ref \$file) eq 'SCALAR') {  
		# they gave me a file name
		# Try to delete an existing file
		if ( -f $file ) {
			my $number_deleted_files = unlink $file;
			if ( $number_deleted_files != 1 ) {
				Carp::croak "Error: File \"$file\" did already exist, but it fails to delete it"; 
			}
		}
		$fh = FileHandle->new (">$file");
		if( !defined $fh) { 
			Carp::croak "Error: File \"$file\" could not be created!\n";
		}
	}
	elsif ((ref \$file) =~ /^(?:REF|GLOB)$/) {
		# either a FileHandle object or a regular file handle
		$fh = $file;
	}
	else {
		Carp::croak "Expected filename or file handle";
	}

	return $fh;
}

sub _init_surface
{
	my( $self, $format ) = @_;

	$self->{'surface'} = Chart::Render->new( $format, $self->{width}, $self->{height} );
}

##  called after the options are set, this method
##  invokes all my private methods to actually
##  draw the chart and plot the data
sub png {
	my ($self,$file,$dataref) = @_;

	my $fh = $self->_open_fh( $file );

	# write the image to the file
	binmode $fh;

	print $fh $self->scalar_png( $dataref );

	# now exit
	return 1;
}


##  called after the options are set, this method
##  invokes all my private methods to actually
##  draw the chart and plot the data
sub cgi_png {
	my( $self, $dataref ) = @_;

	# print the header (ripped the crlf octal from the CGI module)
	if ($self->{no_cache}) {
		print "Content-type: image/png\015\012Pragma: no-cache\015\012\015\012";
	} else {
		print "Content-type: image/png\015\012\015\012";
	}

	$self->png( $dataref, \*STDOUT );

	# now exit
	return 1;
}

##  called after the options are set, this method
##  invokes all my private methods to actually
##  draw the chart and plot the data
sub scalar_png {
	my( $self, $dataref ) = @_;

	# initialise the drawing surface
	$self->_init_surface( "png" );

	# allocate the background color
	$self->_set_colors();

	# make sure the object has its copy of the data
	$self->_copy_data($dataref);

	# do a sanity check on the data, and collect some basic facts
	# about the data
	$self->_check_data();

	# pass off the real work to the appropriate subs
	$self->_draw();

	return $self->{'surface'}->render();
}


##  called after the options are set, this method
##  invokes all my private methods to actually
##  draw the chart and plot the data
sub jpeg {
	my( $self, $file, $dataref ) = @_;

	my $fh = $self->_open_fh( $file );

  # allocate the background color
  $self->_set_colors();

  # make sure the object has its copy of the data
  $self->_copy_data($dataref);

  # do a sanity check on the data, and collect some basic facts
  # about the data
  $self->_check_data;

  # pass off the real work to the appropriate subs
  $self->_draw();

  # now write it to the file handle, and don't forget
  # to be nice to the poor ppl using nt
  binmode $fh;
  print $fh $self->{'gd_obj'}->jpeg([100]);   # high quality need

  # now exit
  return 1;
}

##  called after the options are set, this method
##  invokes all my private methods to actually
##  draw the chart and plot the data
sub cgi_jpeg {
  my $self = shift;
  my $dataref = shift;

  # allocate the background color
  $self->_set_colors();

  # make sure the object has its copy of the data
  $self->_copy_data($dataref);

  # do a sanity check on the data, and collect some basic facts
  # about the data
  $self->_check_data();

  # pass off the real work to the appropriate subs
  $self->_draw();

  # print the header (ripped the crlf octal from the CGI module)
  if ($self->{no_cache}) {
      print "Content-type: image/jpeg\015\012Pragma: no-cache\015\012\015\012";
  } else {
      print "Content-type: image/jpeg\015\012\015\012";
  }

  # now print the png, and binmode it first so nt likes us
  binmode STDOUT;
  print STDOUT $self->{'gd_obj'}->jpeg([100]);

  # now exit
  return 1;
}

##  called after the options are set, this method
##  invokes all my private methods to actually
##  draw the chart and plot the data
sub scalar_jpeg {
  my $self = shift;
  my $dataref = shift;

  # make sure the object has its copy of the data
  $self->_copy_data($dataref);

  # do a sanity check on the data, and collect some basic facts
  # about the data
  $self->_check_data();

  # pass off the real work to the appropriate subs
  $self->_draw();

  # returns the png image as a scalar value, so that
  # the programmer-user can do whatever the heck
  # s/he wants to with it
  $self->{'gd_obj'}->jpeg([100]);
}

sub make_gd {
  my $self = shift;
  my $dataref = shift;

  # allocate the background color
  $self->_set_colors();

  # make sure the object has its copy of the data
  $self->_copy_data($dataref);

  # do a sanity check on the data, and collect some basic facts
  # about the data
  $self->_check_data();

  # pass off the real work to the appropriate subs
  $self->_draw();

  # return the GD::Image object that we've drawn into
  return $self->{'gd_obj'};
}

=item $chart->scalar_svg()

Render the chart to $file in SVG format.

=cut

sub scalar_svg
{
	my( $self, $dataref ) = @_;

	$self->_init_surface( "svg" );

	$self->_copy_data( $dataref );

	$self->_check_data();

	$self->_draw();

	return $self->{'surface'}->render();
}

sub svg
{
	my( $self, $file, $dataref ) = @_;

	my $fh = $self->_open_fh( $file );

	binmode($fh);

	print $fh $self->scalar_svg( $dataref );

	close($fh);
}

##  get the information to turn the chart into an imagemap
sub imagemap_dump {
  my $self = shift;
  my $ref = [];
  my ($i, $j);
 
  # croak if they didn't ask me to remember the data, or if they're asking
  # for the data before I generate it
  unless ($self->{'imagemap'} && $self->{'imagemap_data'}) {
    croak "You need to set the imagemap option to true, and then call the png method, before you can get the imagemap data";
  }

  # can't just return a ref to my internal structures...
  for $i (0..$#{$self->{'imagemap_data'}}) {
    for $j (0..$#{$self->{'imagemap_data'}->[$i]}) {
      $ref->[$i][$j] = [ @{ $self->{'imagemap_data'}->[$i][$j] } ];
    }
  }

  # return their copy
  return $ref;
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

##  initialize all the default options here
sub _init {
  my $self = shift;
  my $x = shift || 400;  # give them a 400x300 image
  my $y = shift || 300;  # unless they say otherwise
  
  $self->{width} = $x;
  $self->{height} = $y;

  # get the gd object
  #$self->{'gd_obj'} = GD::Image->new($x, $y, @_); # Pass other options to GD

  # start keeping track of used space
  $self->{'curr_y_min'} = 0;
  $self->{'curr_y_max'} = $y-1; # Zero-indexed!
  $self->{'curr_x_min'} = 0;
  $self->{'curr_x_max'} = $x-1; # Zero-indexed!

	# define these here to avoid undef warnings
	$self->{y_tick_label_width} = 0;
	$self->{x_tick_label_width} = 0;

warn "_init: curr_y_max=$self->{'curr_y_max'}" if DEBUG;

  # use a 10 pixel border around the whole png
  # Changed to default 0, as it's just annoying otherwise
  $self->{'png_border'} = 0;

  # leave some space around the text fields
  $self->{'text_space'} = 2;

  # and leave some more space around the chart itself
  $self->{'graph_border'} = 10;

  # leave a bit of space inside the legend box
  $self->{'legend_space'} = 4;
  
  # set some default fonts
  $self->{'fonts_default_spec'} = {
	  title => 'Sans-Serif',
	  sub_title => 'Sans-Serif',
	  legend => 'Sans-Serif',
	  label => 'Sans-Serif',
	  tick_label => 'Sans-Serif',
	  series_label => 'Sans-Serif',
  };

  # set some default sizes
  $self->{'font_sizes_default_spec'} = {
	  title => 14,
	  sub_title => 12,
	  legend => 10,
	  label => 11,
	  tick_label => 10,
	  series_label => 10,
  };

  # put the legend on the bottom of the chart
  $self->{'legend'} = 'right';

  # default to an empty list of labels
  $self->{'legend_labels'} = [];

  # use 20 pixel length example lines in the legend
  $self->{'legend_example_size'} = 20;

  # Set the maximum & minimum number of ticks to use.
  $self->{'y_ticks'} = 6;
  $self->{'min_y_ticks'} = 6;
  $self->{'max_y_ticks'} = 100;
  $self->{'x_number_ticks'} = 1;
  $self->{'min_x_ticks'} = 6;
  $self->{'max_x_ticks'} = 100;

  # make the ticks 4 pixels long
  $self->{'tick_len'} = 4;

  # no custom y tick labels
  $self->{'y_tick_labels'} = undef;
  
  # no patterns
  $self->{'patterns'} = [];

  # let the lines in Chart::Lines be 3 pixels wide
  $self->{'brush_size'} = -3;

  # default thickness for all other lines
  $self->{'line_size'} = 1;

  # let the points in Chart::Points and Chart::LinesPoints be 18 pixels wide
  $self->{'pt_size'} = 18;

  # use the old non-spaced bars
  $self->{'spaced_bars'} = TRUE;

  # use the new grey background for the plots
  $self->{'grey_background'} = TRUE;

  # don't default to transparent
  $self->{'transparent'} = undef;

  # default to "normal" x_tick drawing
  $self->{'x_ticks'} = 'normal';

  # we're not a component until Chart::Composite says we are
  $self->{'component'} = undef;

  # don't force the y-axes in a Composite chare to be the same
  $self->{'same_y_axes'} = undef;
  
  # plot rectangeles in the legend instead of lines in a composite chart
  $self->{'legend_example_height'} = undef;
    
  # don't force integer y-ticks
  $self->{'integer_ticks_only'} = undef;
  
  # don't forbid a false zero scale.
  $self->{'include_zero'} = undef;

  # don't waste time/memory by storing imagemap info unless they ask
  $self->{'imagemap'} = undef;

  # default for grid_lines is off
  $self->{grid_lines} = undef;
  $self->{x_grid_lines} = undef;
  $self->{y_grid_lines} = undef;
  $self->{y2_grid_lines} = undef;

  # default for no_cache is false.  (it breaks netscape 4.5)
  $self->{no_cache} = undef;

  $self->{typeStyle} = 'default';

  # default value for skip_y_ticks for the labels
  $self->{skip_y_ticks} = 1;

  # default value for skip_int_ticks only for integer_ticks_only
  $self->{skip_int_ticks} = 1;

  # default value for precision
  $self->{precision} = 3;	

  # default value for legend label values in pie charts
  $self->{legend_label_values} = 'value';
  
  # default value for the labels in a pie chart
  $self->{label_values} = 'percent';
  
  # default position for the y-axes: both, left, right, none
  $self->{y_axes} = 'left';

  # use a logarithmic scale
  $self->{y_axis_scale} = 'linear';
  
  # copies of the current values at the x-ticks function
  $self->{temp_x_min} = 0;
  $self->{temp_x_max} = 0;
  $self->{temp_y_min} = 0;
  $self->{temp_y_max} = 0;

  # Instance for summe
  $self->{sum} = 0;
  
  # Don't sort the data unless they ask
  $self->{'sort'} = undef;
  
  # The Interval for drawing the x-axes in the split module
  $self->{'interval'} = undef;
  
  # The start value for the split chart
  $self->{'start'} = undef;
  
  # How many ticks do i have to draw at the x-axes in one interval of a split-plot?
  $self->{'interval_ticks'} = 6;
  
  # Draw the Lines in the split-chart normal
  $self->{'scale'} = 1;
  
  # Make a x-y plot
  $self->{'xy_plot'} = undef;
  
  # min and max for xy plot
  $self->{'x_min_val'} =1;
  $self->{'x_max_val'} =1;
  
  # use the same error value in ErrorBars
  $self->{'same_error'} = undef;
  

  # Set the minimum and maximum number of circles to draw in a direction chart
  $self->{'min_circles'} = 4;
  $self->{'max_circles'} = 100;
  
  # set the style of a direction diagramm
  $self->{'point'} = TRUE;
  $self->{'line'} = undef;
  $self->{'arrow'} = undef;
  
  # The number of angel axes in a direction Chart
  $self->{'angle_interval'} = 30;
  
  # dont use different 'x_axes' in a direction Chart
  $self->{'pairs'} = undef;
  
  # used function to transform x- and y-tick labels to strings
  $self->{f_x_tick} = \&_default_f_tick;
  $self->{f_y_tick} = \&_default_f_tick;
  $self->{f_z_tick} = \&_default_f_tick;
  # default color specs for various color roles.
  # Subclasses should extend as needed.
  my $d = 0;
  $self->{'colors_default_spec'} = {
    background	=> 'white',
    misc	=> 'black',
    text	=> 'black',
	x_label => 'black',
	x_axis	=> 'black',
    y_label	=> 'black',
	y_axis	=> 'black',
    y_label2	=> 'black',
	y_axis2 => 'black',
    grid_lines	=> 'black',
    grey_background => 'grey',
	legend_background => 'grey',
    (map { ('dataset'.$d => $_, 'neg_dataset'.$d++ => $_) }
		qw( red green blue purple peach orange mauve olive pink light_purple light_blue plum yellow turquoise light_green brown 
		HotPink PaleGreen1 DarkBlue BlueViolet orange2 chocolate1 LightGreen pink light_purple light_blue plum yellow turquoise light_green brown 
		pink PaleGreen2 MediumPurple PeachPuff1 orange3 chocolate2 olive pink light_purple light_blue plum yellow turquoise light_green brown 
		DarkOrange PaleGreen3 SlateBlue BlueViolet PeachPuff2 orange4 chocolate3 LightGreen pink light_purple light_blue plum yellow turquoise light_green brown) ),

  };
  $MAX_DATASET_COLORS = $d-1;
  
  # get default color specs for some color roles from alternate role.
  # Subclasses should extend as needed.
  $self->{'colors_default_role'} = {
    'x_grid_lines'	=> 'grid_lines',
    'y_grid_lines'	=> 'grid_lines',
    'y2_grid_lines'	=> 'grid_lines', # should be added by Char::Composite...
  };

  # and return
  return 1;
}


##  be nice and leave their data alone
sub _copy_data {
  my $self = shift;
  my $extern_ref = shift;
  my ($ref, $i, $j);

  # look to see if they used the other api
  if ($self->{'dataref'}) {
    # we've already got a copy, thanks
    return 1;
  }
  else {
    # get an array reference
    $ref = [];
    
    # loop through and copy
    for $i (0..$#{$extern_ref}) {
      @{ $ref->[$i] } = @{ $extern_ref->[$i] };
## Speedup compared to:
#     for $j (0..$#{$extern_ref->[$i]}) {
#       $ref->[$i][$j] = $extern_ref->[$i][$j];
#     }
    }

    # put it in the object
    $self->{'dataref'} = $ref;
  }
}


##  make sure the data isn't really weird
##  and collect some basic info about it
sub _check_data {
	my $self = shift;
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my $length = 0;

# first make sure there's something there
	unless (scalar (@{$self->{'dataref'}}) >= 2) {
		croak "Call me again when you have some data to chart";
	}

# make sure we don't end up dividing by zero if they ask for
# just one y_tick
	if ($self->{'y_ticks'} <= 1) {
		$self->{'y_ticks'} = 2;
		carp "The number of y_ticks displayed must be at least 2";
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

# find good min and max y-values for the plot
	$self->_find_y_scale;

# find the longest x-tick label
	$self->{'x_tick_label_width'} = 0;
	$self->{'x_tick_label_height'} = 0;
	my $f_x_tick = $self->{'f_x_tick'};
	if (defined $self->{'skip_x_ticks'} && $self->{'skip_x_ticks'} > 1) {
		for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
			my $label = &$f_x_tick($self->{'dataref'}->[0][$_*$self->{'skip_x_ticks'}]);
			my ($w,$h) = $self->string_bounds($font,$fsize,$label);
			$self->{'x_tick_label_width'} = $w if $w > $self->{'x_tick_label_width'};
			$self->{'x_tick_label_height'} = $h if $h > $self->{'x_tick_label_height'};
		}
	}
	else {
		for (@{$self->{'dataref'}->[0]}) {
			next if !defined($_);
			my ($w,$h) = $self->string_bounds($font,$fsize,&$f_x_tick($_));
			$self->{'x_tick_label_width'} = $w if $w > $self->{'x_tick_label_width'};
			$self->{'x_tick_label_height'} = $h if $h > $self->{'x_tick_label_height'};
		}
	}
	if ( $length <= 0 ) { $length = 1; }    # make sure $length is positive and greater 0
		$self->{'x_tick_label_width'} = 1 if $self->{'x_tick_label_width'} <= 0;
	$self->{'x_tick_label_height'} = 1 if $self->{'x_tick_label_height'} <= 0;

# find x-scale, if a x-y plot is wanted
# only makes sense for some charts
	if( !grep { $self->isa( $_ ) } qw( Chart::Lines Chart::Points Chart::ErrorBars ) ) {
		$self->{xy_plot} = FALSE;
	}
	if ( $self->{'xy_plot'} ) {
		$self->_find_x_scale;
	}

	return 1;
}


##  plot the chart to the gd object
sub _draw {
  my $self = shift;
  
## No Longer needed.
#   # use their colors if they want
#   if ($self->{'colors'}) {
#     $self->_set_user_colors();
#   }

## Moved to png(), cgi_png(), etc.
#   # fill in the defaults for the colors
#   $self->_set_colors();

  # leave the appropriate border on the png
  $self->{'curr_x_max'} -= $self->{'png_border'};
  $self->{'curr_x_min'} += $self->{'png_border'};
  $self->{'curr_y_max'} -= $self->{'png_border'};
  $self->{'curr_y_min'} += $self->{'png_border'};

trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

  # draw in the title
  $self->_draw_title();

  # have to leave this here for backwards compatibility
  $self->_draw_sub_title();

trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

  # sort the data if they want to (mainly here to make sure
  # pareto charts get sorted)
  $self->_sort_data() if $self->{'sort'};

  # start drawing the data (most methods in this will be
  # overridden by the derived classes)
  # include _draw_legend() in this to ensure that the legend
  # will be flush with the chart
  $self->_plot();

  # and return
  return 1;
}

sub _font_role_to_font
{
	my( $self, $role ) = @_;

	my $size = $self->{'font_sizes'}->{$role}
		|| $self->{'font_sizes_default_spec'}->{$role};

	my $family = $self->{'fonts'}->{$role}
		|| $self->{'fonts_default_spec'}->{$role};

	if( !defined $family )
	{
		Carp::confess "No role '$role' available in font specs";
	}

	return wantarray ? ($family, $size) : $family;
}

##  specify my colors
sub _set_colors {
  my $self = shift;
  
  if( !$self->{'transparent'} )
  {
	  my $color = $self->_color_role_to_rgb('background');
	  $self->{'surface'}->filled_rectangle( $color, 0, 0,0, $self->{width},$self->{height} );
  }
}

sub _color_role_to_rgb
{
	my( $self, $role ) = @_;

	# Wrap around the dataset colours
	if( $role =~ /^dataset(\d+)$/ && $1 > $MAX_DATASET_COLORS ) {
		$role = 'dataset' . ($1 % $MAX_DATASET_COLORS);
	}

	my $name = $self->{'colors'}->{$role} 
	   || $self->{'colors_default_spec'}->{$role}
	   || $self->{'colors_default_spec'}->{$self->{'colors_default_role'}->{$role}};

	my @rgb = $self->_color_spec_to_rgb($role, $name);

	if( $role =~ /^dataset(\d+)$/ && defined($self->{patterns}->[$1]) ) {
		my $pattern = $self->{patterns}->[$1];
		# we need to merge the pattern and color
		return $self->{surface}->_color_pattern( \@rgb, $pattern );
	}

	return \@rgb;
}

# Return a (list of) color index(es) corresponding to the (list of) role(s)
sub _color_role_to_index
{
	my( $self, @roles ) = @_;
    
	my @indexes;
	foreach my $role (@roles)
	{
		my $index = $self->{'color_table'}->{$role};
		return $index if defined $index;
		
		# Wrap around the dataset colours
		if( $role =~ /^dataset(\d+)$/ && $1 > $MAX_DATASET_COLORS ) {
			$role = 'dataset' . ($1 % $MAX_DATASET_COLORS);
		}

		my $spec = $self->{'colors'}->{$role} 
		   || $self->{'colors_default_spec'}->{$role}
		   || $self->{'colors_default_spec'}->{$self->{'colors_default_role'}->{$role}};
			  
		my @rgb = $self->_color_spec_to_rgb($role, $spec);
			#print STDERR "spec = $spec\n";
		   
		my $string = sprintf " RGB(%d,%d,%d)", map { $_ * 255 } @rgb;
		$index = $self->{'color_table'}->{$string};
		if( !defined $index )
		{
		  $self->{'color_table'}->{$string} = $index;
		}

		$self->{'color_table'}->{$role} = $index;
		push @indexes, $index;
    }
    #print STDERR "Result= ".$indexes[0]."\n";
	
    return (wantarray && @_ > 1 ? @indexes : $indexes[0]);
}
      
sub _color_spec_to_rgb {
    my $self = shift;
    my $role = shift; # for error messages
    my $spec = shift or croak "Undefined spec for role $role to convert to RGB"; # [r,g,b] or name
    my @rgb;
	if ( ref($spec) eq 'ARRAY' ) {
      @rgb = @{ $spec };
      croak "Invalid color RGB array (" . join(',', @rgb) . ") for $role\n" 
        unless @rgb == 3 && grep( ! m/^\d+$/ || $_ > 255, @rgb) == 0;
    }
    elsif ( !ref($spec) ) {
      croak "Unknown named color ($spec) for $role\n"
        unless $NAMED_COLORS{$spec};
      @rgb = @{ $NAMED_COLORS{$spec} };
    }
    else {
      croak "Unrecognized color for $role\n";
    }
    @rgb;
  }

##  draw the title for the chart
sub _draw_title {
  my $self = shift;
  my( $font, $fsize ) = $self->_font_role_to_font( 'title' );
  my $color = defined $self->{'colors'}{'title'} ?
      			$self->_color_role_to_rgb('title') :
      			$self->_color_role_to_rgb('text');
  my ($h, $w, @lines, $x, $y);

  # split the title into lines
  return unless $self->{'title'};
  @lines = split (/\\n/, $self->{'title'});

  # Find where we start
  $x = ($self->{'curr_x_max'} - $self->{'curr_x_min'}) / 2
         + $self->{'curr_x_min'};
  $y = $self->{'curr_y_min'}; # There's nothing above title so no point adding text_space
  for(0..$#lines) {
	  ($w,$h) = $self->string_bounds($font, $fsize, $lines[$_]);
	  $y = ($self->{'curr_y_min'} += $h);
	  $self->{'surface'}->string($color,$font,$fsize,$x-$w/2,$y,0,$lines[$_]);
	  $y = ($self->{'curr_y_min'} += $self->{'text_space'});
  }

  # and return
  return 1;
}

##  pesky backwards-compatible sub
sub _draw_sub_title {
  my $self = shift;
  my( $font, $fsize ) = $self->_font_role_to_font( 'sub_title' );
  my $color = defined $self->{'colors'}{'sub_title'} ?
      			$self->_color_role_to_rgb('sub_title') :
      			$self->_color_role_to_rgb('text');
  my ($h, $w, @lines, $x, $y);

  # split the title into lines
  return unless $self->{'sub_title'};
  @lines = split (/\\n/, $self->{'sub_title'});

  # Find where we start
  $x = ($self->{'curr_x_max'} - $self->{'curr_x_min'}) / 2
         + $self->{'curr_x_min'};
  $y = ($self->{'curr_y_min'} += $self->{'text_space'});
  for(0..$#lines) {
	  ($w,$h) = $self->string_bounds($font,$fsize,$lines[$_]);
	  $y = ($self->{'curr_y_min'} += $self->{'text_space'} + $h);
	  $self->{'surface'}->string($color,$font,$fsize,$x-$w/2,$y,0,$lines[$_]);
  }

  # and return
  return 1;
}


##  sort the data nicely (mostly for the pareto charts and xy-plots)
sub _sort_data {
   my $self = shift;
   my $data_ref = $self->{'dataref'};
   my @data = @{$self->{'dataref'}};
   my @sort_index;

   #sort the data with slices
   @sort_index = sort { $data[0][$a] <=> $data[0][$b] } (0..scalar(@{$data[1]})-1);
   for (1..$#data) {
       @{$self->{'dataref'}->[$_]} = @{$self->{'dataref'}->[$_]}[@sort_index];
   }
   @{$data_ref->[0]} = sort {$a <=> $b} @{$data_ref->[0]};

   #finally return
   return 1;
}

#For a xy-plot do the same for the x values, as _find_y_scale does for the y values!
sub _find_x_scale {
    my $self = shift;
    my @data = @{$self->{'dataref'}};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
    my ($i, $j);
    my ($d_min, $d_max);
    my ($p_min, $p_max, $f_min, $f_max);
    my ($tickInterval, $tickCount, $skip);
    my @tickLabels;
    my $maxtickLabelLen = 0;
	my $maxtickLabelWidth = 0;
	my $maxtickLabelHeight = 0;
    
    #look, if we have numbers
    for $i (0..($self->{'num_datasets'})) {
        for $j (0..($self->{'num_datapoints'}-1)) {
                #the following regular Expression matches all possible numbers, including scientific numbers!!
                if ($data[$i][$j] !~ m/^[+-]?((\.\d+)|(\d+\.?\d*))([eE][+-]?\d+)?[fFdD]?$/ ) {
                   croak "<$i,$j = $data[$i][$j]> You should give me numbers for drawing a xy plot!\n";
                }
        }
    }
    
    #find the dataset min and max
    ($d_min, $d_max) = $self->_find_x_range();

   # Force the inclusion of zero if the user has requested it.
   if( $self->{'include_zero'} )    {
       if( ($d_min * $d_max) > 0 ) {	# If both are non zero and of the same sign.
         if( $d_min > 0 ) {	# If the whole scale is positive.
             $d_min = 0;
         }
         else	{			# The scale is entirely negative.
    		$d_max = 0;
         }
      }
   }

   # Calculate the width of the dataset. (posibly modified by the user)
   my $d_width = $d_max - $d_min;

   # If the width of the range is zero, forcibly widen it
   # (to avoid division by zero errors elsewhere in the code).
   if( 0 == $d_width )  {
       $d_min--;
       $d_max++;
       $d_width = 2;
   }

   # Descale the range by converting the dataset width into
   # a floating point exponent & mantisa pair.
   my( $rangeExponent, $rangeMantisa ) = $self->_sepFP( $d_width );
   my $rangeMuliplier = 10 ** $rangeExponent;

   # Find what tick
   # to use & how many ticks to plot,
   # round the plot min & max to suatable round numbers.
   ($tickInterval, $tickCount, $p_min, $p_max)
    = $self->_calcXTickInterval($d_min/$rangeMuliplier, $d_max/$rangeMuliplier,
				$f_min, $f_max,
				$self->{'min_x_ticks'}, $self->{'max_x_ticks'});
   # Restore the tickInterval etc to the correct scale
   $_ *= $rangeMuliplier foreach($tickInterval, $p_min, $p_max);

	my $f_x_tick = $self->{f_x_tick};
	if( !defined $f_x_tick || $self->{f_x_tick} == \&_default_f_tick )
	{
		# Get the precision for the labels
		my $precision = $self->{'precision'};
		$precision = 0 if ($tickInterval-int($tickInterval) == 0);

		$f_x_tick = sub { sprintf("%.".$precision."f", $_[0] ) };
	}

	# Now sort out an array of tick labels.
	for( my $labelNum = $p_min; $labelNum<=$p_max; $labelNum+=$tickInterval ) {
		my $labelText = &$f_x_tick( $labelNum );
		push @tickLabels, $labelText;

		$maxtickLabelLen = length $labelText if $maxtickLabelLen < length $labelText;
		my ($w,$h) = $self->string_bounds($font,$fsize,$labelText);
		$maxtickLabelWidth = $w if $w > $maxtickLabelWidth;
		$maxtickLabelHeight = $h if $h > $maxtickLabelHeight;
   }

   # Store the calculated data.
   $self->{'x_min_val'} = $p_min;
   $self->{'x_max_val'} = $p_max;
   $self->{'x_tick_labels'} = \@tickLabels;
   $self->{'x_tick_label_length'} = $maxtickLabelLen;
   $self->{'x_tick_label_width'} = $maxtickLabelWidth;
   $self->{'x_tick_label_height'} = $maxtickLabelHeight;
   $self->{'x_number_ticks'} = $tickCount;
   return 1;
}

##  find good values for the minimum and maximum y-value on the chart
# New version, re-written by David Pottage of Tao Group.
# This code is *AS IS* and comes with *NO WARRANTY*
#
# This Sub calculates correct values for the following class local variables,
# if they have not been set by the user.
#
# max_val, min_val: 	The maximum and minimum values for the y axis.
# 
# y_ticks:				The number of ticks to plot on the y scale, including
#						the end points. e.g. If the scale runs from 0 to 50,
#						with ticks every 10, y_ticks will have the value of 6.
# 
# y_tick_labels:		An array of strings, each is a label for the y axis.
# 
# y_tick_labels_length:	The length to allow for B tick labels. (How long is
#						the longest?)	

sub _find_y_scale
{
	my $self = shift;

# Predeclare vars.
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my ($d_min, $d_max);		# Dataset min & max.
	my ($p_min, $p_max);		# Plot min & max.
	my ($tickInterval, $tickCount, $skip);
	my @tickLabels;				# List of labels for each tick.
	my $maxtickLabelLen = 0;	# The length of the longest tick label.
	my $maxtickLabelWidth = 0;	# The length in pixels of the longest tick label.
	my $maxtickLabelHeight = 0;	# The height in pixels of the tallest tick label.
	my $prec_test=0;			# Boolean which indicate if precision < |rangeExponent|
	my $temp_rangeExponent;
	my ( $rangeExponent, $rangeMantisa );

# Find the datatset minimum and maximum.
	($d_min, $d_max) = $self->_find_y_range();

# Force the inclusion of zero if the user has requested it.
	if( $self->{'include_zero'} )
	{
		if( ($d_min * $d_max) > 0 )	# If both are non zero and of the same sign.
		{
			if( $d_min > 0 )	# If the whole scale is positive.
			{
				$d_min = 0;
			}
			else				# The scale is entirely negative.
			{
				$d_max = 0;
			}
		}
	}

	if( $self->{'integer_ticks_only'} )
	{
# Allow the dataset range to be overidden by the user.
# f_min/max are booleans which indicate that the min & max should not be modified.
		$d_min = $self->{'min_val'} if defined($self->{'min_val'});
		$d_max = $self->{'max_val'} if defined($self->{'max_val'});

# Assert against the min is larger than the max.
		if( $d_min > $d_max ) {
			croak "The the specified 'min_val' & 'max_val' values are reversed (min > max: $d_min>$d_max)";
		} elsif( $d_min == $d_max ) {
			$d_max++;
		}
# The user asked for integer ticks, force the limits to integers.
# & work out the range directly.
#$p_min = $self->_round2Tick($d_min, 1, -1);
#$p_max = $self->_round2Tick($d_max, 1, 1);

		$skip = $self->{skip_int_ticks};
		$skip = 1 if $skip < 1;      

		$p_min = $self->_round2Tick($d_min, 1, -1);
		$p_max = $self->_round2Tick($d_max, 1, 1);

		$tickInterval = $skip;
		$tickCount = ($p_max - $p_min ) / $skip + 1;

# Now sort out an array of tick labels.
		for( my $labelNum = $p_min; $labelNum<=$p_max; $labelNum+=$tickInterval )
		{
			my $labelText;
			if( defined $self->{f_y_tick} )
			{	
# Is _default_f_tick function used?
				if ( $self->{f_y_tick} == \&_default_f_tick) {
					$labelText = sprintf("%d", $labelNum);
				} else {
					$labelText = $self->{f_y_tick}->($labelNum);
				}
			}

			else
			{
				$labelText = sprintf("%d", $labelNum);
			}	

			push @tickLabels, $labelText;
			my ($w,$h) = $self->string_bounds($font,$fsize,$labelText);
			$maxtickLabelLen = length $labelText if $maxtickLabelLen < length $labelText;
			$maxtickLabelWidth = $w if $maxtickLabelWidth < $w;
			$maxtickLabelHeight = $h if $maxtickLabelHeight < $h;
		}

	}
	else
	{  
# Allow the dataset range to be overidden by the user.
		$d_min = $self->{'min_val'} if defined $self->{min_val};
		$d_max = $self->{'max_val'} if defined $self->{max_val};

# Assert against the min is larger than the max.
		if( $d_min > $d_max )
		{
			croak "The the specified 'min_val' & 'max_val' values are reversed (min > max: $d_min>$d_max)";
		}

# Calculate the width of the dataset. (posibly modified by the user)
		my $d_width = $d_max - $d_min;

# If the width of the range is zero, forcibly widen it
# (to avoid division by zero errors elsewhere in the code).
		if( $d_width == 0 )
		{
			$d_min--, $d_max++, $d_width = 2;
		}

# Descale the range by converting the dataset width into
# a floating point exponent & mantisa pair.
		( $rangeExponent, $rangeMantisa ) = $self->_sepFP( $d_width );
		my $rangeMuliplier = 10 ** $rangeExponent;

# Find what tick
# to use & how many ticks to plot,
# round the plot min & max to suatable round numbers.
		($tickInterval, $tickCount, $p_min, $p_max)
			= $self->_calcTickInterval($d_min/$rangeMuliplier, $d_max/$rangeMuliplier,
					defined($self->{min_val}), defined($self->{max_val}),
					$self->{'min_y_ticks'}, $self->{'max_y_ticks'});
# Restore the tickInterval etc to the correct scale
		$_ *= $rangeMuliplier foreach($tickInterval, $p_min, $p_max);

# Is precision < |rangeExponent|?
		if ($rangeExponent <0) {
			$temp_rangeExponent = -$rangeExponent;
		}
		else {
			$temp_rangeExponent = $rangeExponent;
		}

#get the precision for the labels
		my $precision = $self->{'precision'};
		$precision = 0 if ($tickInterval-int($tickInterval) == 0);

		if(
				$temp_rangeExponent != 0 &&
				$rangeExponent < 0 &&
				$temp_rangeExponent > $precision
		  ) {
			$prec_test =1;
		}

		my $f_y_tick = $self->{f_y_tick};
		if( !defined $f_y_tick || $f_y_tick == \&_default_f_tick )
		{
			# if precision <|rangeExponent| print the labels with exponents
			if( !$prec_test )
			{
				$f_y_tick = sub { sprintf("%.".$precision."f", $_[0]) };
			}
		}
# Now sort out an array of tick labels.
		for( my $labelNum = $p_min; $labelNum<=$p_max; $labelNum+=$tickInterval )
		{
			my $labelText = &$f_y_tick( $labelNum );
			push @tickLabels, $labelText;
			my ($w,$h) = $self->string_bounds($font,$fsize,$labelText);
			$maxtickLabelLen = length $labelText if $maxtickLabelLen < length $labelText;
			$maxtickLabelWidth = $w if $maxtickLabelWidth < $w;
			$maxtickLabelHeight = $h if $maxtickLabelHeight < $h;
		}
	}

# Store the calculated data.
	$self->{'min_val'} = $p_min;
	$self->{'max_val'} = $p_max;
	$self->{'y_ticks'} = $tickCount;
	$self->{'y_tick_labels'} = \@tickLabels;
	$self->{'y_tick_label_length'} = $maxtickLabelLen;
	$self->{'y_tick_label_width'} = $maxtickLabelWidth;
	$self->{'y_tick_label_height'} = $maxtickLabelHeight > 0 ?
		$maxtickLabelHeight :
		0; 
	$self->{y_tick_interval} = $tickInterval;
	$self->{y_range_exponent} = $rangeExponent;

#warn "$self: y_tick_label_width = $maxtickLabelWidth";

# and return.
	return 1;
}



# Calculates the tick  in normalised units.
# Result will need multiplying by the multipler to get the true tick interval.
# written by David Pottage of Tao Group.
sub _calcTickInterval
{       my $self = shift;
	my(
		$min, $max,		# The dataset min & max.
		$minF, $maxF,	# Indicates if those min/max are fixed.
		$minTicks, $maxTicks,	# The minimum & maximum number of ticks.
	) = @_;
	
	# Verify the supplied 'min_y_ticks' & 'max_y_ticks' are sensible.
	if( $minTicks < 2 )
	{
		#print STDERR "Chart::Base : Incorrect value for 'min_y_ticks', too small (less than 2).\n";
		$minTicks = 2;
	}
	
	if( $maxTicks < 5*$minTicks  )
	{
		#print STDERR "Chart::Base : Incorrect value for 'max_y_ticks', too small (<5*minTicks).\n";
		$maxTicks = 5*$minTicks;
	}
	
	my $width = $max - $min;
	my @divisorList;
	
	for( my $baseMul = 1; ; $baseMul *= 10 )
	{
		TRY: foreach my $tryMul (1, 2, 5)
		{
			# Calc a fresh, smaller tick interval.
			my $divisor = $baseMul * $tryMul;
			
			# Count the number of ticks.
			my ($tickCount, $pMin, $pMax) = $self->_countTicks($min, $max, 1/$divisor);
			
			# Look a the number of ticks.
			if( $maxTicks < $tickCount )
			{
				# If it is to high, Backtrack.
				$divisor = pop @divisorList;
                                # just for security:
                                if ( !defined($divisor) || $divisor == 0 ) { $divisor = 1; } 
				($tickCount, $pMin, $pMax) = $self->_countTicks($min, $max, 1/$divisor);
				#print STDERR "\nChart::Base : Caution: Tick limit of $maxTicks exceeded. Backing of to an interval of ".1/$divisor." which plots $tickCount ticks\n";
				return(1/$divisor, $tickCount, $pMin, $pMax);
			}
			elsif( $minTicks > $tickCount )
			{
				# If it is to low, try again.
				next TRY;
			}
			else
			{
				# Store the divisor for possible later backtracking.
				push @divisorList, $divisor;
			
				# if the min or max is fixed, check they will fit in the interval.
				next TRY if( $minF && ( int ($min*$divisor) != ($min*$divisor) ) );
				next TRY if( $maxF && ( int ($max*$divisor) != ($max*$divisor) ) );
				
				# If everything passes the tests, return.
				return(1/$divisor, $tickCount, $pMin, $pMax)
			}
		}
	}
	
	die "can't happen!";
}
sub _calcXTickInterval
{       my $self = shift;
	my(
		$min, $max,		# The dataset min & max.
		$minF, $maxF,	# Indicates if those min/max are fixed.
		$minTicks, $maxTicks,	# The minimum & maximum number of ticks.
	) = @_;

	# Verify the supplied 'min_y_ticks' & 'max_y_ticks' are sensible.
	if( $minTicks < 2 )
	{
		#print STDERR "Chart::Base : Incorrect value for 'min_y_ticks', too small.\n";
		$minTicks = 2;
	}

	if( $maxTicks < 5*$minTicks  )
	{
		#print STDERR "Chart::Base : Incorrect value for 'max_y_ticks', to small.\n";
		$maxTicks = 5*$minTicks;
	}

	my $width = $max - $min;
	my @divisorList;

	for( my $baseMul = 1; ; $baseMul *= 10 )
	{
		TRY: foreach my $tryMul (1, 2, 5)
		{
			# Calc a fresh, smaller tick interval.
			my $divisor = $baseMul * $tryMul;

			# Count the number of ticks.
			my ($tickCount, $pMin, $pMax) = $self->_countTicks($min, $max, 1/$divisor);

			# Look a the number of ticks.
			if( $maxTicks < $tickCount )
			{
				# If it is to high, Backtrack.
				$divisor = pop @divisorList;
                                # just for security:
                                if ( !defined($divisor) || $divisor == 0 ) { $divisor = 1; }
				($tickCount, $pMin, $pMax) = $self->_countTicks($min, $max, 1/$divisor);
				#print STDERR "\nChart::Base : Caution: Tick limit of $maxTicks exceeded. Backing of to an interval of ".1/$divisor." which plots $tickCount ticks\n";
				return(1/$divisor, $tickCount, $pMin, $pMax);
			}
			elsif( $minTicks > $tickCount )
			{
				# If it is to low, try again.
				next TRY;
			}
			else
			{
				# Store the divisor for possible later backtracking.
				push @divisorList, $divisor;

				# if the min or max is fixed, check they will fit in the interval.
				next TRY if( $minF && ( int ($min*$divisor) != ($min*$divisor) ) );
				next TRY if( $maxF && ( int ($max*$divisor) != ($max*$divisor) ) );

				# If everything passes the tests, return.
				return(1/$divisor, $tickCount, $pMin, $pMax)
			}
		}
	}

	die "can't happen!";
}

# Works out how many ticks would be displayed at that interval
# e.g min=2, max=5, interval=1, result is 4 ticks.
# written by David Pottage of Tao Group.
sub _countTicks
{
        my $self = shift;
	my( $min, $max, $interval) = @_;
	
	my $minR = $self->_round2Tick( $min, $interval, -1);
	my $maxR = $self->_round2Tick( $max, $interval, 1);
	
	my $tickCount = ( $maxR/$interval ) - ( $minR/$interval ) +1;
	
	return ($tickCount, $minR, $maxR);
}

# Rounds up or down to the next tick of interval size.
# $roundUP can be +1 or -1 to indicate if rounding should be up or down.
# written by David Pottage of Tao Group.
sub _round2Tick
{
        my $self = shift;
	my($input, $interval, $roundUP) = @_;
	return $input if $interval == 0;
	die unless 1 == $roundUP*$roundUP;
	
	my $intN  = int ($input/$interval);
	my $fracN = ($input/$interval) - $intN;
	
	my $retN = ( ( 0 == $fracN ) || ( ($roundUP * $fracN) < 0 ) )
		? $intN
		: $intN + $roundUP;
	
	return $retN * $interval;
}

# Seperates a number into it's base 10 floating point exponent & mantisa.
# written by David Pottage of Tao Group.
sub _sepFP
{
        my $self = shift;
	my($num) = @_;
	return(0,0) if $num == 0;
	
	my $sign = ( $num > 0 ) ? 1 : -1;
	$num *= $sign;
	
	my $exponent = int ( log($num)/log(10) );
	my $mantisa  = $sign *($num / (10**$exponent) );
	
	return ( $exponent, $mantisa );
}

sub _find_y_range {
	my $self = shift;
	my $data = $self->{'dataref'};

	my $max = undef;
	my $min = undef;
	for my $dataset ( @$data[1..$#$data] ) {
		for my $datum ( @$dataset ) {
		   next if !defined $datum;
		   ($min = $max = $datum), next if !defined $max;
		   $max = $datum, next if $datum > $max;
		   $min = $datum, next if $datum < $min;
	   }
	}
	($min, $max);
}

sub _find_x_range {
  my $self = shift;
  my $data = $self->{'dataref'};

  my $max = undef;
  my $min = undef;

    for my $datum ( @{$data->[0]} ) {
      if ( defined $datum ) {
        if ( defined $max ) {
          if ( $datum > $max ) { $max = $datum }
          elsif ( $datum < $min ) { $min = $datum }
        }
        else { $min = $max = $datum }
      }
    }

 return ($min, $max);
}
## main sub that controls all the plotting of the actual chart
sub _plot {
  my $self = shift;

  # draw the legend first
  $self->_draw_legend;

  # mark off the graph_border space
  $self->{'curr_x_min'} += $self->{'graph_border'};
  $self->{'curr_x_max'} -= $self->{'graph_border'};
  $self->{'curr_y_min'} += $self->{'graph_border'};
  $self->{'curr_y_max'} -= $self->{'graph_border'};

trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

  # draw the x- and y-axis labels
  $self->_draw_x_label if $self->{'x_label'};
  $self->_draw_y_label('left') if $self->{'y_label'};
  $self->_draw_y_label('right') if $self->{'y_label2'};

trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

  # draw the ticks and tick labels
  $self->_draw_ticks;
  
trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

  # give the plot a grey background if they want it
  $self->_grey_background if $self->{'grey_background'};
  
  # hilite any columns they might want hiliting
  if( $self->{'hilite_columns'} ) {
	  $self->_draw_hilited_columns;
  }
  
  #draw the ticks again if grey_background has ruined it in a Direction Chart.
  if ($self->{'grey_background'} && $self->isa("Chart::Direction")) {
    $self->_draw_ticks;
  }
  $self->_draw_grid_lines if $self->{'grid_lines'};
  $self->_draw_x_grid_lines if $self->{'x_grid_lines'};
  $self->_draw_y_grid_lines if $self->{'y_grid_lines'};
  $self->_draw_y2_grid_lines if $self->{'y2_grid_lines'};

  # plot the data
  $self->_draw_data();
  
  # and return
  return 1;
}

# string_bounds is used so much we'll provide a utility method here
sub string_bounds
{
	my( $self, $font, $size, $string ) = @_;

	Carp::confess( "surface undefined" ) if !defined $self->{'surface'};
	return $self->{'surface'}->string_bounds( $font, $size, $string );
}

sub string_width
{
	my( $self, $font, $size, $string ) = @_;

	my( $w, $h ) = $self->{'surface'}->string_bounds( $font, $size, $string );

	return $w;
}

sub string_height
{
	my( $self, $font, $size, $string ) = @_;

	my( $w, $h ) = $self->{'surface'}->string_bounds( $font, $size, $string );

	return $h;
}

# Utility functions to set the correct line thickness before
# we draw lines (i.e. so the user can easily create
# a higher res chart)
sub _gd_line {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

sub _gd_line_aa {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

sub _gd_rectangle {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

sub _gd_string($$$$$$$) {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

sub _gd_string_width {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

sub _gd_string_height {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

sub _gd_string_dimensions {
	Carp::confess "Use of deprecated function ".(caller(0))[3];
}

##  let them know what all the pretty colors mean
sub _draw_legend {
  my $self = shift;
  my ($length,$height);
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
  my ($axes_space,$x1,$x2);

  # check to see if legend type is none..
  if ($self->{'legend'} =~ /^none$/) {
    return 0;
  }
  # check to see if they have as many labels as datasets,
  # warn them if not
  if (($#{$self->{'legend_labels'}} >= 0) && 
       ((scalar(@{$self->{'legend_labels'}})) != $self->{'num_datasets'})) {
    carp "The number of legend labels and datasets doesn\'t match";
  }

  # init a field to store the length of the longest legend label
  unless ($self->{'max_legend_label_width'}) {
    $self->{'max_legend_label_width'} = 0;
  }

  # fill in the legend labels, find the longest one
  for (1..$self->{'num_datasets'}) {
    unless ($self->{'legend_labels'}[$_-1]) {
      $self->{'legend_labels'}[$_-1] = "Dataset $_";
    }
	($length,$height) = $self->string_bounds($font,$fsize,$self->{'legend_labels'}[$_-1]);
    if ($length > $self->{'max_legend_label_width'}) {
      $self->{'max_legend_label_width'} = $length;
	  $self->{'max_legend_label_height'} = $height;
    }
  }
      
  # find the base x values
  $x1 = $self->{'curr_x_min'} + $self->{'graph_border'};
  $x2 = $self->{'curr_x_max'} - $self->{'graph_border'};

  if ($self->{'y_axes'}) {
	  $axes_space = $self->{'y_tick_label_width'}
		        	+ $self->{'tick_len'} + (2 * $self->{'text_space'});
	  if ($self->{'y_axes'} =~ /^right$/i) {
	     $x2 -= $axes_space;
	  }
	  elsif ($self->{'y_axes'} =~ /^both$/i) {
	     $x2 -= $axes_space;
	     $x1 += $axes_space;
	  }
	  else {
	     $x1 += $axes_space;
	  }
  }

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
  } else {
    carp "I can't put a legend there (at ".$self->{'legend'}.")\n";
  }

  # and return
  return 1;
}

sub _draw_legend_box {
	my( $self, $x, $y, $x2, $y2 ) = @_;

	my $line_size = $self->{'line_size'};
	my $legend_border_size = $self->{'legend_border_size'};
	$legend_border_size = $line_size if !defined $legend_border_size;

	# get the miscellaneous color
	my $misccolor = $self->_color_role_to_rgb('misc');

	if( $self->{'legend_background'} )
	{
		$self->{'surface'}->filled_rectangle(
				$self->_color_role_to_rgb('legend_background'),
				0,
				$x, $y, $x2, $y2);
	}

	$self->{'surface'}->rectangle(
			$misccolor,
			$legend_border_size,
			$x, $y, $x2, $y2);
}

sub _draw_legend_entry_example {
	my( $self, $color, $x, $y, $h, $shape ) = @_;

	my $legend_example_size = $self->{'legend_example_size'};

	$y -= $h/2; # vertically centre the example

	# draw the example line
	$self->{'surface'}->line($color,
			$h/4,
			$x, $y, 
			$x + $legend_example_size, $y);

	# draw the point
	if( defined $shape )
	{
		my $x3 = $x + $legend_example_size/2;
		$self->{'surface'}->point($color,$h,$x3,$y,0,$shape);
	}
}

sub _draw_legend_entry {
	my( $self, $color, $x, $y, $h, $shape, $label ) = @_;

	my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
	my $misccolor = $self->_color_role_to_rgb('misc');

	$self->_draw_legend_entry_example($color, $x, $y, $h, $shape);

	# adjust the x-y coordinates for the start of the label
	$x += $self->{'legend_example_size'} + (2 * $self->{'text_space'});

	# now draw the label
	$self->{'surface'}->string($misccolor, $font, $fsize, $x, $y, 0, $label);
}

## put the legend on the bottom of the chart
sub _draw_bottom_legend {
  my ($self,$x1,$x2) = @_;
  my @labels = @{$self->{'legend_labels'}};
  my ($y1, $x3, $y2, $empty_width, $max_label_width, $cols, $rows, $color, $brush);
  my ($col_width, $row_height, $r, $c, $index, $x, $y, $w, $h, $axes_space);
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
  my $line_size = $self->{'line_size'};

  # get the size of the font
  # ($h, $w) = ($font->height, $font->width);
  $h = $self->{'max_legend_label_height'};

  # get the miscellaneous color
  my $misccolor = $self->_color_role_to_rgb('misc');

  # figure out how wide the columns need to be, and how many we
  # can fit in the space available
  $empty_width = ($x2 - $x1) - (2 * $self->{'legend_space'});
  $max_label_width = $self->{'max_legend_label_width'}
    + (4 * $self->{'text_space'}) + $self->{'legend_example_size'};
  $cols = int ($empty_width / $max_label_width);
  unless ($cols) {
    $cols = 1;
  }
  $col_width = $empty_width / $cols;

  # figure out how many rows we need, remember how tall they are
  $rows = int ($self->{'num_datasets'} / $cols);
  unless (($self->{'num_datasets'} % $cols) == 0) {
    $rows++;
  }
  unless ($rows) {
    $rows = 1;
  }
  $row_height = $h + $self->{'text_space'};

  # box the legend off
  $y1 = $self->{'curr_y_max'} - $self->{'text_space'}
          - ($rows * $row_height) - (2 * $self->{'legend_space'});
  $y2 = $self->{'curr_y_max'};
  $self->_draw_legend_box( $x1, $y1, $x2, $y2 );
  $x1 += $self->{'legend_space'} + $self->{'text_space'};
  $x2 -= $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};
  $y2 -= $self->{'legend_space'} + $self->{'text_space'};

  # draw in the actual legend
  for $r (0..$rows-1) {
    for $c (0..$cols-1) {
      $index = ($r * $cols) + $c;  # find the index in the label array
      if ($labels[$index]) {
		# get the color
        $color = $self->_color_role_to_rgb('dataset'.$index); 

        # get the x-y coordinate for the start of the example line
		$x = $x1 + ($col_width * $c);
        $y = $y1 + ($row_height * $r) + $h;
	
        # get the shape style (if any)
		my $shape = $self->{'pointStyle'.($index+1)};

		$self->_draw_legend_entry($color, $x, $y, $h, $shape, $labels[$index]);
      }
    }
  }

	# Mark off the space used
	$self->{'curr_y_max'} -= ($rows * $row_height) + $self->{'text_space'}
			      + (2 * $self->{'legend_space'}); 

  # now return
  return 1;
}


## put the legend on the right of the chart
sub _draw_right_legend {
  my $self = shift;
  my @labels = @{$self->{'legend_labels'}};
  my ($x1, $x2, $x3, $y1, $y2, $width, $color, $misccolor, $w, $h, $brush);
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
  my $line_size = $self->{'line_size'};
 
  # get the size of the font
  #($h, $w) = ($font->height, $font->width);
  $h = $self->{'max_legend_label_height'};

  # get the miscellaneous color
  $misccolor = $self->_color_role_to_rgb('misc');

  # find out how wide the largest label is
  $width = (2 * $self->{'text_space'})
    + $self->{'max_legend_label_width'}
    + $self->{'legend_example_size'}
    + (2 * $self->{'legend_space'});

  # get some starting x-y values
  $x1 = $self->{'curr_x_max'} - $width;
  $x2 = $self->{'curr_x_max'};
  $y1 = $self->{'curr_y_min'} + $self->{'graph_border'} ;
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + ($self->{'num_datasets'} * ($h + $self->{'text_space'}))
	  + (2 * $self->{'legend_space'});

  # box the legend off
  $self->_draw_legend_box( $x1, $y1, $x2, $y2 );

  # leave that nice space inside the legend box
  $x1 += $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};

	my $row_height = $self->{'text_space'} + $h;

  # now draw the actual legend
  foreach my $index (0..$#labels) {
# color of the datasets in the legend
	  $color = $self->_color_role_to_rgb('dataset'.$index);

# find the x-y coords
	  my $x = $x1;
	  my $y = $y1 + ($index * $row_height) + $h;

# get the shape style (if any)
	  my $shape = $self->{'pointStyle'.($index+1)};

	  $self->_draw_legend_entry($color, $x, $y, $h, $shape, $labels[$index]);
  }

  # mark off the used space
  $self->{'curr_x_max'} -= $width;

  # and return
  return 1;
}


## put the legend on top of the chart
sub _draw_top_legend {
  my ($self,$x1,$x2) = @_;
  my @labels = @{$self->{'legend_labels'}};
  my ($y1, $x3, $y2, $empty_width, $max_label_width, $cols, $rows, $color, $brush);
  my ($col_width, $row_height, $r, $c, $index, $x, $y, $w, $h, $axes_space);
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
  my $line_size = $self->{'line_size'};
  my $misccolor = $self->_color_role_to_rgb('misc');

  # get the size of the font
  # ($h, $w) = ($font->height, $font->width);
  $h = $self->{'max_legend_label_height'};

  # figure out how wide the columns can be, and how many will fit
  $empty_width = ($x2 - $x1) - (2 * $self->{'legend_space'});
  $max_label_width = (4 * $self->{'text_space'})
    + $self->{'max_legend_label_width'}
    + $self->{'legend_example_size'};
  $cols = int ($empty_width / $max_label_width);
  unless ($cols) {
    $cols = 1;
  }
  $col_width = $empty_width / $cols;

  # figure out how many rows we need and remember how tall they are
  $rows = int ($self->{'num_datasets'} / $cols);
  unless (($self->{'num_datasets'} % $cols) == 0) {
    $rows++;
  }
  unless ($rows) {
    $rows = 1;
  }
  $row_height = $h + $self->{'text_space'};

  # box the legend off
  $y1 = $self->{'curr_y_min'};
  $y2 = $self->{'curr_y_min'} + $self->{'text_space'}
          + ($rows * $row_height) + (2 * $self->{'legend_space'});
  $self->_draw_legend_box( $x1, $y1, $x2, $y2 );

  # leave some space inside the legend
  $x1 += $self->{'legend_space'} + $self->{'text_space'};
  $x2 -= $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};
  $y2 -= $self->{'legend_space'} + $self->{'text_space'};

  # draw in the actual legend
  for $r (0..$rows-1) {
    for $c (0..$cols-1) {
      $index = ($r * $cols) + $c;  # find the index in the label array
      if ($labels[$index]) {
	# get the color
        $color = $self->_color_role_to_rgb('dataset'.$index); 
        
	# find the x-y coords
	$x = $x1 + ($col_width * $c);
        $y = $y1 + ($row_height * $r) + $h;
	
        # get the shape style (if any)
		my $shape = $self->{'pointStyle'.($index+1)};

		$self->_draw_legend_entry($color, $x, $y, $h, $shape, $labels[$index]);
      }
    }
  }
      
  # mark off the space used
  $self->{'curr_y_min'} += ($rows * $row_height) + $self->{'text_space'}
			      + 2 * $self->{'legend_space'}; 

  # now return
  return 1;
}


## put the legend on the left of the chart
sub _draw_left_legend {
  my $self = shift;
  my @labels = @{$self->{'legend_labels'}};
  my ($x1, $x2, $x3, $y1, $y2, $width, $color, $misccolor, $w, $h, $brush);
  my( $font, $fsize ) = $self->_font_role_to_font( 'legend' );
  my $line_size = $self->{'line_size'};
 
  # get the size of the font
  #($h, $w) = ($font->height, $font->width);
  $h = $self->{'max_legend_label_height'};

  # get the miscellaneous color
  $misccolor = $self->_color_role_to_rgb('misc');

  # find out how wide the largest label is
  $width = (2 * $self->{'text_space'})
    + $self->{'max_legend_label_width'}
    + $self->{'legend_example_size'}
    + (2 * $self->{'legend_space'});

  # get some base x-y coordinates
  $x1 = $self->{'curr_x_min'};
  $x2 = $self->{'curr_x_min'} + $width;
  $y1 = $self->{'curr_y_min'} + $self->{'graph_border'} ;
  $y2 = $self->{'curr_y_min'} + $self->{'graph_border'} + $self->{'text_space'}
          + ($self->{'num_datasets'} * ($h + $self->{'text_space'}))
	  + (2 * $self->{'legend_space'});

  # box the legend off
  $self->_draw_legend_box( $x1, $y1, $x2, $y2 );

  # leave that nice space inside the legend box
  $x1 += $self->{'legend_space'};
  $y1 += $self->{'legend_space'} + $self->{'text_space'};

	my $row_height = $self->{'text_space'} + $h;

  # now draw the actual legend
  foreach my $index (0..$#labels) {
# color of the datasets in the legend
	  $color = $self->_color_role_to_rgb('dataset'.$index);

# find the x-y coords
	  my $x = $x1;
	  my $y = $y1 + ($index * $row_height) + $h;

# get the shape style (if any)
	  my $shape = $self->{'pointStyle'.($index+1)};

	  $self->_draw_legend_entry($color, $x, $y, $h, $shape, $labels[$index]);
  }

  # mark off the used space
  $self->{'curr_x_min'} += $width;

  # and return
  return 1;
}


## draw the label for the x-axis
sub _draw_x_label {  
  my $self = shift;
  my $label = $self->{'x_label'};
  my( $font, $fsize ) = $self->_font_role_to_font( 'label' );
  my $color;
  my ($w, $h, $x, $y);

  #get the right color
  $color = $self->_color_role_to_rgb('x_label')
	  || $self->_color_role_to_rgb('text');
  
  # get the size of the font
  #($h, $w) = ($font->height, $font->width);
  ($w,$h) = $self->string_bounds($font,$fsize,$label);

  # make sure it goes in the right place
  $x = ($self->{'curr_x_max'} - $self->{'curr_x_min'}) / 2
         + $self->{'curr_x_min'} - $w / 2;
  $y = $self->{'curr_y_max'} - $self->{'text_space'};

  # now write it
  $self->{'surface'}->string($color, $font, $fsize, $x, $y, 0, $label);

print STDERR "_draw_x_label: curr_y_max=$self->{'curr_y_max'} => " if DEBUG;

  # mark the space written to as used
  $self->{'curr_y_max'} -= $h + 2 * $self->{'text_space'};

warn "$self->{'curr_y_max'}" if DEBUG;

  # and return
  return 1;
}


## draw the label for the y-axis
sub _draw_y_label {
  my $self = shift;
  my $side = shift;
  my( $font, $fsize ) = $self->_font_role_to_font( 'label' );
  my ($label, $w, $h, $x, $y, $color);

  # get the label
  if ($side eq 'left') {
    $label = $self->{'y_label'};
    $color = $self->_color_role_to_rgb('y_label');
  }
  elsif ($side eq 'right') {
    $label = $self->{'y_label2'};
    $color = $self->_color_role_to_rgb('y_label2');
  }

  # get the size of the label
  ($w,$h) = $self->string_bounds($font,$fsize,$label);

  # make sure it goes in the right place
  if ($side eq 'left') {
    $x = $self->{'curr_x_min'} + $self->{'text_space'};
  }
  elsif ($side eq 'right') {
    $x = $self->{'curr_x_max'} - $self->{'text_space'} - $h;
  }
  $y = ($self->{'curr_y_max'} - $self->{'curr_y_min'}) / 2
         + $self->{'curr_y_min'} + $w / 2;

  # write it
  $self->{'surface'}->string($color,$font,$fsize,$x,$y,ANGLE_VERTICAL,$label);

  # mark the space written to as used
  if ($side eq 'left') {
    $self->{'curr_x_min'} += $h + 2 * $self->{'text_space'};
  }
  elsif ($side eq 'right') {
    $self->{'curr_x_max'} -= $h + 2 * $self->{'text_space'};
  }

  # now return
  return 1;
}


## draw the ticks and tick labels
sub _draw_ticks {
  my $self = shift;

  #if the user wants an xy_plot, calculate the x-ticks too
  if ( $self->{'xy_plot'} && ($self->isa('Chart::Lines') || $self->isa('Chart::Points') || $self->isa('Chart::ErrorBars')) ) {
     $self->_draw_x_number_ticks;
  }
  else { # draw the x ticks with strings
     $self->_draw_x_ticks;
  }

  my $side = 0;
  if( $self->{y_axes} eq 'both' || $self->{y_axes} eq 'left' ) {
	  $side += CHART_LEFT;
  }
  if( $self->{y_axes} eq 'both' || $self->{y_axes} eq 'right' ) {
	  $side += CHART_RIGHT;
  }
  $side = 0 if defined($self->{y_axis}) && $self->{y_axis} eq 'none';

  # now the y ticks
  $self->_draw_y_ticks( $side );
  # then return
  return 1;
}

sub _draw_x_number_ticks {
	my $self = shift;
	my $data = $self->{'dataref'};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my $line_size = $self->{'line_size'};
	my $textcolor = $self->_color_role_to_rgb('text');
	my $misccolor = $self->_color_role_to_rgb('misc');
	my ($h, $w, $x1, $y1, ,$y2, $x2, $delta, $width, $label);
	my @labels = @{$self->{'x_tick_labels'}};

	$self->{'grid_data'}->{'x'} = [];

#get height and width of the font
#($h, $w) = ($font->height, $font->width);
	$h = $self->{'x_tick_label_height'};

#store actual borders, for a possible later repair
	$self->{'temp_x_min'} = $self->{'curr_x_min'};
	$self->{'temp_x_max'} = $self->{'curr_x_max'};
	$self->{'temp_y_max'} = $self->{'curr_y_max'};
	$self->{'temp_y_min'} = $self->{'curr_y_min'};

	$x1 = $self->{curr_x_min};
	my $y_axis_width = $self->{y_tick_label_width} + 2*$self->{text_space} + $self->{tick_len};

#get the right x-value and width
#The one and only way to get the RIGHT x value and the width
	if ($self->{'y_axes'} =~ /^right$/i) {
		$width = $self->{'curr_x_max'} - $x1 - $y_axis_width;
	}
	elsif ($self->{'y_axes'} =~ /^both$/i) {
		$x1 += $y_axis_width;
		$width = $self->{'curr_x_max'} - $x1 - $y_axis_width;
	}
	else {
# Make sure the last label can be printed
		my $label = $self->{f_x_tick}->($labels[$#labels]);
		my $need = $self->string_width($font,$fsize,$label) / 2;
		if( $need > $self->{'graph_border'} )
		{
			$self->{'curr_x_max'} -= $need - $self->{'graph_border'};
		}

		$x1 += $y_axis_width;
		$width = $self->{'curr_x_max'} - $x1;
	}

#get the delta value
	$delta = $width / ($self->{'x_number_ticks'}-1 ) ;

#draw the labels
	$y2 =$y1;

	if ($self->{'x_ticks'} =~ /^normal/i ) {  #just normal ticks
#get the point for updating later
		$y1 = $self->{'curr_y_max'} - 2*$self->{'text_space'} - $h - $self->{'tick_len'};
#get the start point
		$y2 = $y1 + $self->{'tick_len'} + $self->{'text_space'} + $h;
		for (0..$#labels){
			$label = $labels[$_];
			$x2 = $x1 + ($delta * $_) - ($self->string_width($font,$fsize,$label)/2) ;
			$self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0, $label);
		}
	}
	elsif ($self->{'x_ticks'} =~ /^staggered/i ) {  #staggered ticks
#get the point for updating later
		$y1 = $self->{'curr_y_max'} - 2*$self->{'text_space'} - 2*$h - $self->{'tick_len'};

		for (0..$#labels) {
			$label = $labels[$_];
			$x2 = $x1 + ($delta * $_) - ($self->string_width($font,$fsize,$label)/2);
			unless ($_%2) {
				$y2 = $y1 + 2*$h + $self->{'text_space'} + $self->{'tick_len'};
				$self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0, $label);
			}
			else {
				$y2 = $y1  + $h + 2*$self->{'text_space'} + $self->{'tick_len'};
				$self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, 0, $label);
			}
		}
	}
	elsif ($self->{'x_ticks'} =~ /^vertical/i ) {  #vertical ticks
#get the point for updating later
		$y1 = $self->{'curr_y_max'} - 2*$self->{'text_space'} - $self->{'x_tick_label_width'} - $self->{'tick_len'};
		for (0..$#labels){
			$label = $labels[$_];

#get the start point
			$y2 = $y1  + $self->{'tick_len'} + $self->string_width($font,$fsize,$label) + $self->{'text_space'};
			$x2 = $x1 + ($delta * $_) - ($h /2);
			$self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, ANGLE_VERTICAL, $label);
		}

	}

	else {
		carp "I don't understand the type of x-ticks you specified";
	}
#update the curr y max value
	$self->{'curr_y_max'} = $y1;

	trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

#draw the ticks
	$y1 =$self->{'curr_y_max'};
	$y2 =$self->{'curr_y_max'} + $self->{'tick_len'};
	for(0..$#labels ) {
		$x2 = $x1 + ($delta * $_);
		$self->{'surface'}->line( $misccolor,$line_size,$x2, $y1, $x2, $y2);
		if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
			$self->{'grid_data'}->{'x'}->[$_] = $x2;
		}
	}

	return 1;
}

## draw the x-ticks and their labels
sub _draw_x_ticks {
	my $self = shift;

	my $data = $self->{'dataref'};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );

	if( exists($self->{'x_axis'}) and $self->{'x_axis'} eq 'none' )
	{
		return;
	}

	$self->{'grid_data'}->{'x'} = [];

# allow for the amount of space the y-ticks will push the
# axes over to the right

	my( $x1, $y1, $width );

	$x1 = $self->{curr_x_min};
	my $y_axis_width = $self->{y_tick_label_width} + 2*$self->{text_space} + $self->{tick_len};

#The one and only way to get the RIGHT x value and the width
	if ($self->{'y_axes'} =~ /^right$/i) {
		$width = $self->{'curr_x_max'} - $x1 - $y_axis_width;
	}
	elsif ($self->{'y_axes'} =~ /^both$/i) {
		$x1 += $y_axis_width;
		$width = $self->{'curr_x_max'} - $x1 - $y_axis_width;
	}
	else {
# Make sure the last label can be printed
		my $label = $self->{f_x_tick}->($data->[0][$#{$data->[0]}]);
		my $need = $self->string_width($font,$fsize,$label) / 2;
		if( defined($self->{'graph_border'}) and $need > $self->{'graph_border'} )
		{
			$self->{'curr_x_max'} -= $need - $self->{'graph_border'};
		}

		$x1 += $y_axis_width;
		$width = $self->{'curr_x_max'} - $x1;
	}

# the same for the y value, but not so tricky
	$y1 = $self->{'curr_y_max'} - $self->{'text_space'};

	$self->_draw_x_ticks_actual( $x1, $y1, $width );
}

sub _draw_x_ticks_actual
{
	my( $self, $x1, $y1, $width ) = @_;

	my $data = $self->{'dataref'};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );

	my $line_size = $self->{'line_size'};
	my $textcolor = $self->_color_role_to_rgb('x_axis');
	$textcolor ||= $self->_color_role_to_rgb('text');
	my $misccolor = $self->_color_role_to_rgb('x_axis');
	$misccolor ||= $self->_color_role_to_rgb('misc');

	my( $x2, $y2 );

	my $label;

	# get the height of the x-labels (required for vertical/staggered)
	my $h = $self->{'x_tick_label_height'};
  
	# get the delta value
	my $delta = $width / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'}-1 : 1);

	# Discrete data, so don't extend to y/y2 axis
	if( $self->{component} || !$self->{xy_plot} ) {
		# compress the x-axis so labels are centered on data points
		$delta = $width / ($self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1);
		$width -= $delta;
		$x1 += $delta/2;
	}

	if( !defined($self->{'skip_x_ticks'}) || $self->{'skip_x_ticks'} == 0 ) {
		$self->{'skip_x_ticks'} = 1;
	}

  # Change to staggered if the labels would overlap in 'normal' mode
  if( $self->{'x_ticks'} =~ /^normal$/i ) {
	  my ($label_need,$label_got);
	  if( $self->{'custom_x_ticks'} && @{$self->{'custom_x_ticks'}} ) {
		  $label_got = $width/@{$self->{'custom_x_ticks'}};
	  } elsif( $self->{'num_datapoints'} > 0 ) {
		  $label_got = $width/$self->{'num_datapoints'};
	  } else {
		  $label_got = $width;
	  }
	  $label_need = $self->{'x_tick_label_width'} / $self->{'skip_x_ticks'};
	  if( $label_got <= $label_need ) {
		$self->{'x_ticks'} = 'staggered';
	  }
  }

trace("$self->{x_ticks} at $y1: max-width=$self->{x_tick_label_width}, max-height=$h");

  # now draw the labels 
  if ($self->{'x_ticks'} =~ /^normal$/i) { # normal ticks
     if ($self->{'skip_x_ticks'} >1) { # draw only every nth tick and label
      for (0..int (($self->{'num_datapoints'} - 1) / $self->{'skip_x_ticks'})) {
        if ( defined($data->[0][$_*$self->{'skip_x_ticks'}]) ) {
           $label = $self->{f_x_tick}->($data->[0][$_*$self->{'skip_x_ticks'}]);
           $x2 = $x1 + ($delta * ($_ * $self->{'skip_x_ticks'})) 
	         - $self->string_width($font,$fsize,$label) / 2;
           $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y1, 0, $label);
        }
      }     
    }
    elsif ($self->{'custom_x_ticks'}) { # draw only the ticks they wanted
     for (@{$self->{'custom_x_ticks'}}) {
         if ( defined($data->[0][$_]) ) {
             $label = $self->{f_x_tick}->($data->[0][$_]);
             $x2 = $x1 + ($delta*$_) - $self->string_width($font,$fsize,$label) / 2;
             $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y1, 0, $label);
         }
     }
    }
    else {
      for (0..$self->{'num_datapoints'}-1) {
        if ( defined($data->[0][$_]) ) {
          $label = $self->{f_x_tick}->($data->[0][$_]);
          $x2 = $x1 + ($delta*$_) - $self->string_width($font,$fsize,$label) / 2;
          $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y1, 0, $label);
        }
      }
    }
  }

  elsif ($self->{'x_ticks'} =~ /^staggered$/i) { # staggered ticks
    if ($self->{'skip_x_ticks'}>1) {
      my $stag = 0;
      for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
        if ( defined($data->[0][$_*$self->{'skip_x_ticks'}]) ) {
           $x2 = $x1 + ($delta * ($_ * $self->{'skip_x_ticks'})) 
	        - $self->string_width($font,$fsize,$self->{f_x_tick}->($data->[0][$_*$self->{'skip_x_ticks'}])) / 2;
           if (($stag % 2) == 1) {
             $y1 -= $self->{'text_space'} + $h;
           }
           $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y1, 0, 
	                          $self->{f_x_tick}->($data->[0][$_*$self->{'skip_x_ticks'}]));
           if (($stag % 2) == 1) {
             $y1 += $self->{'text_space'} + $h;
           }
	   $stag++;
         }
      }
    }
    elsif ($self->{'custom_x_ticks'}) {
      my $stag = 0;
      for (sort (@{$self->{'custom_x_ticks'}})) { # sort to make it look good
        if ( defined($data->[0][$_]) ) {
           $x2 = $x1 + ($delta*$_) - $self->string_width($font,$fsize,$self->{f_x_tick}->($data->[0][$_])) / 2;
           if (($stag % 2) == 1) {
             $y1 -= $self->{'text_space'} + $h;
           }
           $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y1, 0, $self->{f_x_tick}->($data->[0][$_]));
           if (($stag % 2) == 1) {
             $y1 += $self->{'text_space'} + $h;
           }
	   $stag++;
         }
      }
    }
    else {
      for (0..$self->{'num_datapoints'}-1) {
        if ( defined($self->{f_x_tick}->($data->[0][$_]) ) ) {
           $x2 = $x1 + ($delta*$_) - $self->string_width($font,$fsize,$self->{f_x_tick}->($data->[0][$_])) / 2;
           if (($_ % 2) == 1) {
             $y1 -= $self->{'text_space'} + $h;
           }
           $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y1, 0, $self->{f_x_tick}->($data->[0][$_]));
           if (($_ % 2) == 1) {
             $y1 += $self->{'text_space'} + $h;
           }
        }
      }
    }
  }
  elsif ($self->{'x_ticks'} =~ /^vertical$/i) { # vertical ticks
    $y1 = $self->{'curr_y_max'} - $self->{'text_space'};
    if ($self->{'skip_x_ticks'} > 1) {
      for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
        if ( defined($_) ) {
		  $label = $self->{f_x_tick}->($data->[0][$_*$self->{'skip_x_ticks'}]);
		  my $w = $self->string_width($font,$fsize,$label);
          $x2 = $x1 + ($delta*($_*$self->{'skip_x_ticks'})) - $h/2;
          $y2 = $y1 - $self->{'x_tick_label_width'} + $w;
          $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, ANGLE_VERTICAL, $label);
        }
      }
    }
    elsif ($self->{'custom_x_ticks'}) {
      for (@{$self->{'custom_x_ticks'}}) {
        if ( defined($_) ) {
		   $label = $self->{f_x_tick}->($data->[0][$_]);
		   my $w = $self->string_width($font,$fsize,$label);
           $x2 = $x1 + ($delta*$_) - $h/2;
           $y2 = $y1 - $self->{'x_tick_label_width'} + $w;
           $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, ANGLE_VERTICAL,$label);
         }
      }
    }
    else {
      for (0..$self->{'num_datapoints'}-1) {
        if ( defined($_) ) {
			$label = $self->{f_x_tick}->($data->[0][$_]);
			my $w = $self->string_width($font,$fsize,$label);
           $x2 = $x1 + ($delta*$_) - $h/2;
           $y2 = $y1 - $self->{'x_tick_label_width'} + $w;
           $self->{'surface'}->string($textcolor, $font,$fsize, $x2, $y2, ANGLE_VERTICAL, $label);
         }
      }
    }
  }
  else { # error time
    carp "I don't understand the type of x-ticks you specified";
  }

  # update the current y-max value
  if ($self->{'x_ticks'} =~ /^normal$/i) {
    $self->{'curr_y_max'} -= $h + (2 * $self->{'text_space'});
  }
  elsif ($self->{'x_ticks'} =~ /^staggered$/i) {
    $self->{'curr_y_max'} -= (2 * $h) + (2 * $self->{'text_space'});
  }
  elsif ($self->{'x_ticks'} =~ /^vertical$/i) {
    $self->{'curr_y_max'} -= $self->{'x_tick_label_width'}
                               + (2 * $self->{'text_space'});
  }

  # now plot the ticks
  $y1 = $self->{'curr_y_max'};
  $y2 = $self->{'curr_y_max'} - $self->{'tick_len'};
  if ($self->{'skip_x_ticks'} > 1) {
	 trace("using skip_x_ticks [$self->{skip_x_ticks}]");
    for (0..int(($self->{'num_datapoints'}-1)/$self->{'skip_x_ticks'})) {
      $x2 = $x1 + ($delta*($_*$self->{'skip_x_ticks'}));
      $self->{'surface'}->line($misccolor, $line_size, $x2, $y1, $x2, $y2);
      if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
	$self->{'grid_data'}->{'x'}->[$_] = $x2;
      }
    }
  }
  elsif ($self->{'custom_x_ticks'}) {
	 trace("using custom_x_ticks");
    for (@{$self->{'custom_x_ticks'}}) {
      $x2 = $x1 + ($delta*$_);
      $self->{'surface'}->line( $misccolor,$line_size,$x2, $y1, $x2, $y2);
      if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
	$self->{'grid_data'}->{'x'}->[$_] = $x2;
      }
    }
  }
  else {
	 trace("using default labels");
    for (0..$self->{'num_datapoints'}-1) {
      $x2 = $x1 + ($delta*$_);
      $self->{'surface'}->line( $misccolor,$line_size,$x2, $y1, $x2, $y2);
      if ($self->{'grid_lines'} || $self->{'x_grid_lines'}) {
	$self->{'grid_data'}->{'x'}->[$_] = $x2;
      }
    }
  }

  # update the current y-max value
  $self->{'curr_y_max'} -= $self->{'tick_len'};
trace("curr_*=".join(',',@$self{qw( curr_x_min curr_y_min curr_x_max curr_y_max)}));

}

##  draw the y-ticks and their labels
sub _draw_y_ticks {
	my( $self, $side ) = @_;
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my $textcolor = $self->_color_role_to_rgb($side & CHART_LEFT ? 'y_axis' : 'y_axis2');
	$textcolor ||= $self->_color_role_to_rgb('text');
	my $misccolor = $self->_color_role_to_rgb($side & CHART_LEFT ? 'y_axis' : 'y_axis2');
	$misccolor ||= $self->_color_role_to_rgb('misc');
	my @labels = @{$self->{'y_tick_labels'}};
	my ($height, $delta);

	return if !$side; # none

	$self->{grid_data}->{'y'} = [];
	$self->{grid_data}->{'y2'} = [];

# Check we aren't hard up against the top
	if( (my $diff = $self->{'curr_y_min'} - ($self->{'y_tick_label_height'}/2)) < 0 ) {
		$self->{'curr_y_min'} -= int($diff); # Diff is negative!
	}

	my $axis_width = $self->{tick_len} + 2*$self->{text_space} + $self->{y_tick_label_width};
	if( $side & CHART_LEFT ) {
		$self->{'curr_x_min'} += $axis_width;
	}
	if( $side & CHART_RIGHT ) {
		$self->{'curr_x_max'} -= $axis_width;
	}

	if( $self->{y_axis_scale} eq 'logarithmic' )
	{
		return $self->_draw_y_logarithmic_ticks( $side );
	}

	$height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
	$self->{'y_ticks'} = 2 if $self->{'y_ticks'} < 2;
	$delta = $height / ($self->{'y_ticks'} - 1);

	for(0..$#labels) {
		my $label = $labels[$_];
		my $y = $self->{curr_y_max} - $delta * $_;
		my( $w, $h ) = $self->string_bounds($font,$fsize,$label);
		if( $side & CHART_LEFT ) {
			push @{$self->{'grid_data'}->{'y'}}, $y;
			my $x = $self->{curr_x_min};
			$self->{surface}->line( $misccolor, 1,
				$x - $self->{tick_len}, $y,
				$x, $y,
			);
			$x -= $axis_width - $self->{y_tick_label_width} + $w;
			$self->{'surface'}->string($textcolor, $font, $fsize,
				$x, $y + $h/2, 0,
				$label
			);
		}
		if( $side & CHART_RIGHT ) {
			push @{$self->{'grid_data'}->{'y2'}}, $y;
			my $x = $self->{curr_x_max};
			$self->{surface}->line( $misccolor, 1,
				$x, $y,
				$x + $self->{tick_len}, $y,
			);
			$x += $self->{tick_len} + $self->{text_space};
			$self->{'surface'}->string($textcolor, $font, $fsize,
				$x, $y + $h/2, 0,
				$label
			);
		}
	}

# and return
	return 1;
}

sub _draw_y_logarithmic_ticks
{
	my( $self, $side ) = @_;
	my $data = $self->{'dataref'};
	my( $font, $fsize ) = $self->_font_role_to_font( 'tick_label' );
	my $textcolor = $self->_color_role_to_rgb(
		$side eq 'left' ? 'y_axis' : 'y_axis2'
	);
	$textcolor ||= $self->_color_role_to_rgb('text');
	my $misccolor = $self->_color_role_to_rgb(
		$side eq 'left' ? 'y_axis' : 'y_axis2'
	);
	$misccolor ||= $self->_color_role_to_rgb('misc');

	my $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
	my $scale = log($self->{max_val} - $self->{min_val});

	my @steps;
	for(0 .. abs($self->{y_range_exponent})) {
		push @steps, 10 ** ($self->{y_range_exponent} > 0 ? $_ : -$_);
	}

	my $axis_width = 2 * $self->{text_space} + $self->{y_tick_label_width} + $self->{tick_len};

	my $prev_y = $self->{curr_y_max};
	foreach my $step (@steps) {
		my $next_y = $self->{curr_y_max} - $height * log($step*10)/$scale;
		for(1 .. 9) {
			my $v = $step * $_;
			last if $v > $self->{max_val};
			my $y = $self->{curr_y_max} - $height * log($v)/$scale;
			push @{$self->{'grid_data'}->{'y'}}, $y;
			push @{$self->{'grid_data'}->{'y2'}}, $y;

			my( $w, $h ) = $self->{surface}->string_bounds( $font, $fsize, $v );

			if( $v != $step && ($y + $h > $prev_y || $y - $h <= $next_y) ) {
				next;
			}
			$prev_y = $y;

			if( $side & CHART_LEFT ) {
				my $x = $self->{curr_x_min};
				$self->{surface}->line( $misccolor, 1,
					$x - $self->{tick_len}, $y,
					$x, $y,
				);
				$x -= $axis_width - $self->{y_tick_label_width} + $w;
				$self->{'surface'}->string($textcolor, $font, $fsize,
					$x, $y + $h/2, 0,
					$v
				);
			}
			if( $side & CHART_RIGHT ) {
				my $x = $self->{curr_x_max};
				$self->{surface}->line( $misccolor, 1,
					$x, $y,
					$x + $self->{tick_len}, $y,
				);
				$x += $self->{tick_len} + $self->{text_space};
				$self->{'surface'}->string($textcolor, $font, $fsize,
					$x, $y + $h/2, 0,
					$v
				);
			}
		}
	}
}

##  put a grey background on the plot of the data itself
sub _grey_background
{
	my( $self ) = @_;

	# draw it
	$self->{'surface'}->filled_rectangle(
			$self->_color_role_to_rgb('grey_background'),
			0,
			$self->{'curr_x_min'},
			$self->{'curr_y_min'},
			$self->{'curr_x_max'},
			$self->{'curr_y_max'});

	# now return
	return 1;
}

# Column highlighting
sub _draw_hilited_columns {
	my $self = shift;
	my $color = $self->_color_role_to_rgb('hilite_columns') || return;
	my $width = $self->{'curr_x_max'} - $self->{'curr_x_min'};
	my $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
	my $delta1 = ( $self->{'num_datapoints'} > 0 ) ? $width / ($self->{'num_datapoints'}*1) : $width;
	my $x1 = $self->{'curr_x_min'};
	my $y1 = $self->{'curr_y_min'};
	my $y2 = $self->{'curr_y_max'};
	for(0..$self->{'num_datapoints'})
	{
		if($self->{'hilite_columns'}->[$_]) {
			$self->{'gd_obj'}->filledRectangle (
				$self->{'curr_x_min'}+$delta1*$_,
				$self->{'curr_y_min'},
				$self->{'curr_x_min'}+$delta1*($_+1),
				$self->{'curr_y_max'},
				$color);
		}
	}
}

# draw grid_lines 
sub _draw_grid_lines {
  my $self = shift;
  $self->_draw_x_grid_lines();
  $self->_draw_y_grid_lines();
  $self->_draw_y2_grid_lines();
  return 1;
}

sub _draw_x_grid_lines {
  my $self = shift;
  my $grid_role = shift || 'x_grid_lines';
  my $gridcolor = $self->_color_role_to_rgb($grid_role);
  my ($x, $y, $i);

  foreach $x (@{ $self->{grid_data}->{'x'} }) {
    if ( defined $x) {
       $self->{'surface'}->line( $gridcolor,1,($x, $self->{'curr_y_min'} + 1), $x, ($self->{'curr_y_max'} - 1));
    }
  }
  return 1;
}

sub _draw_y_grid_lines {
	my $self = shift;
	my $grid_role = shift || 'y_grid_lines';
	my $gridcolor = $self->_color_role_to_rgb($grid_role);
	my $line_size = $self->{'line_size'};
	my ($x, $y, $i);

#Look if I'm an HorizontalBars object
	if ($self->isa('Chart::HorizontalBars')) {
		for ($i = 0; $i < ($#{ $self->{grid_data}->{'y'} } ) + 1; $i++) {
			$y = $self->{grid_data}->{'y'}->[$i];
			$self->{'surface'}->line( $gridcolor,$line_size,($self->{'curr_x_min'} + 1), $y, $self->{'curr_x_max'}, $y);
		}
	} else {
# loop for y values is a little different. This is to discard the first
# and last values we were given - the top/bottom of the chart area.
		for ($i = 1; $i < @{$self->{grid_data}->{'y'}}; $i++) {
			$y = $self->{grid_data}->{'y'}->[$i];
			$self->{'surface'}->line( $gridcolor,$line_size,$self->{'curr_x_min'}, $y, $self->{'curr_x_max'}, $y);
		}
	}
	return 1;
}

sub _draw_y2_grid_lines {
  my $self = shift;
  my $grid_role = shift || 'y2_grid_lines';
  my $gridcolor = $self->_color_role_to_rgb($grid_role);
  my $line_size = $self->{'line_size'};
  my ($x, $y, $i);

  #Look if I'm an HorizontalBars object
  if ($self->isa('Chart::HorizontalBars')) {
      for ($i = 0; $i < ($#{ $self->{grid_data}->{'y'} } ) +1 ; $i++) {
        $y = $self->{grid_data}->{'y'}->[$i];
        $self->{'surface'}->line( $gridcolor,$line_size,($self->{'curr_x_min'} + 1), $y, $self->{'curr_x_max'}, $y);
      }
  }
  else {
  # loop for y2 values is a little different. This is to discard the first 
  # and last values we were given - the top/bottom of the chart area.
   for ($i = 1; $i < $#{ $self->{grid_data}->{'y2'} }; $i++) {
     $y = $self->{grid_data}->{'y2'}->[$i];
     $self->{'surface'}->line( $gridcolor,$line_size,($self->{'curr_x_min'} + 1), $y, $self->{'curr_x_max'}, $y);
   }
  }
  return 1;
}

#
# default tick conversion function
# This function is pointed to be $self->{f_x_tick} resp. $self->{f_y_tick}
# if the user does not provide another function
#
sub _default_f_tick {
    my $label     = shift;
    
    return $label;
}


=back

=head1 COMMON PROPERTIES

To modify the appearance of Chart use the set() method.

	$obj->set(
		text_space => 2,
		legend => 'bottom'
	);

=over 4

=item draw_box => "none"

Supress drawing of the box around the plot.

=item f_x_tick => sub {}

=item f_y_tick => sub {}

=item f_z_tick => sub {}

Customize the value shown on an axis. The sub reference takes one argument (the value to be rendered).

=item legend => "right"

Legend placement. "right", "left", "bottom", "top" or "none" to not display.

=item max_y_ticks => 6

The maximum number of ticks to plot on the y scale, including the end points. e.g. If the scale runs from 0 to 50, with ticks every 10, max_y_ticks will have the value of 6.

=item title

Title for the chart.

=item x_axis => "none"

Supress drawing of the x-axis;

=item x_label

Label for the x-axis.

=item x_ticks => { "normal", "staggered", "vertical" }

Show x-axis labels normal (horizontal), staggered, or vertical.

=item y_axis => "none"

Supress drawing of the y-axis.

=item y_label, y_label2

Labels for the left and right y-axes.

=cut


## be a good module and return positive
1;

