#====================================================================
#  Chart::LinesPoints
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
# $RCSfile: LinesPoints.pm,v $ $Revision: 1.4 $ $Date: 2003/02/14 14:10:36 $
# $Author: dassing $
# $Log: LinesPoints.pm,v $
# Revision 1.4  2003/02/14 14:10:36  dassing
# First setup to cvs
#
#====================================================================
package Chart::LinesPoints;

use Chart::Base 3.0;
use Chart::Lines 3.0;

@ISA = qw(Chart::Lines);
$VERSION = $Chart::Base::VERSION;

use strict;

#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#

sub _init
{
	my $self = shift;

	$self->SUPER::_init( @_ );

	for(1..10)
	{
		$self->{"pointStyle$_"} = "circle";
	}
}

#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

## be a good module and return 1
1;
