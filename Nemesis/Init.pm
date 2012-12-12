package Nemesis::Init;
{
	use Nemesis::Env;
	use Nemesis::Interfaces;
	use Nemesis::IO;
	use Nemesis::Process;
	use Nemesis::Inject;
	use Nemesis::ModuleLoader;
	use Nemesis::Session;
	use Carp qw( croak );

	sub new
	{
		my $package = shift;
		bless( {}, $package );
		$package->{'Env'} = new Nemesis::Env( Init => $package );
		$package->{'Io'} =
			new Nemesis::IO( debug   => 1,
							 verbose => 0,
							 Init    => $package
			);
		$package->{'Interfaces'} = new Nemesis::Interfaces( Init => $package );
		$package->{'Session'} = new Nemesis::Session( Init => $package );
		if ( $package->{'Session'}->exists("default_session") )
		{
			$package->{'Session'}->restore("default_session");
		} else
		{
			$package->{'Session'}->initialize("default_session");
		}
		$package->{'ModuleLoader'} =
			Nemesis::ModuleLoader->new( Init => $package );

#Load all plugins in plugin directory and passes to the construtor of the modules those objs
#
		if ( !$package->{'Env'}->check_root() )
		{
			$package->{'Io'}->print_alert(
				"Insufficient permission, something can go really wrong switching to debug mode"
			);
			$package->{'Io'}->set_debug(1);    #If no root given, debug on
		}
		$0 = "SpikeNemesis";
		return $package;
	}

	sub sighandler()
	{
		my $self = shift;
		$self->on_exit();
	}

	sub on_exit()
	{
		my $self = shift;
		if ( exists( $self->{'Session'} ) )
		{
			$self->{'Session'}->save();
		}
		$self->{'ModuleLoader'}->execute_on_all("clear");
		exit;
	}

	sub getIO
	{
		my $package = shift;
		return $package->{'Io'};
	}

	sub getEnv
	{
		my $package = shift;
		return $package->{'Env'};
	}

	sub getInterfaces
	{
		my $package = shift;
		return $package->{'Interfaces'};
	}

	sub getSession
	{
		my $package = shift;
		return $package->{'Session'};
	}

	sub getModuleLoader
	{
		my $package = shift;
		return $package->{'ModuleLoader'};
	}
}
1;
