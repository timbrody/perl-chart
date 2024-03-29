package Chart::Debug;

# based on LWP::Debug

require Exporter;
@ISA = qw( Exporter );
@EXPORT_OK = qw(level trace debug);

use Carp ();

my @levels = qw(trace debug);
%current_level = ();

sub import
{
	my $pack = shift;
	my $callpkg = caller(0);
	my @symbols = ();
	my @levels = ();
	for (@_) {
		if (/^[-+]/) {
			push(@levels, $_);
		}
		else {
			push(@symbols, $_);
		}
	}
	Exporter::export($pack, $callpkg, @symbols);
	level(@levels);
}

sub level
{
    for (@_) {
	if ($_ eq '+') {              # all on
	    # switch on all levels
	    %current_level = map { $_ => 1 } @levels;
	}
	elsif ($_ eq '-') {           # all off
	    %current_level = ();
	}
	elsif (/^([-+])(\w+)$/) {
	    $current_level{$2} = $1 eq '+';
	}
	else {
	    Carp::croak("Illegal level format $_");
	}
    }
}


sub trace  { _log(@_) if $current_level{'trace'}; }
sub debug  { _log(@_) if $current_level{'debug'}; }

sub _log
{
    my $msg = shift;
    $msg .= "\n" unless $msg =~ /\n$/;  # ensure trailing "\n"

    my($package,$filename,$line,$sub) = caller(2);
    print STDERR "$sub: $msg";
}

1;
