package Nemesis::Init;
{
    use Nemesis::Env;
    use Nemesis::Interfaces;
    use Nemesis::IO;
    use Nemesis::Process;
    use Nemesis::ModuleLoader;
    use Carp qw( croak );

    sub new {

        my $package = shift;
        bless( {}, $package );
        $package->{'Env'} = new Nemesis::Env;

        $package->{'Io'} = new Nemesis::IO(
            debug   => 1,
            verbose => 0,
            env     => $package->{'Env'}
        );

        $package->{'Interfaces'} =
            new Nemesis::Interfaces( IO => $package->{'Io'} );
        $package->{'ModuleLoader'} = Nemesis::ModuleLoader->new(
            IO         => $package->{'Io'},
            interfaces => $package->{'Interfaces'},
            env        => $package->{'Env'}
            )
            ; #Load all plugins in plugin directory and passes to the construtor of the modules those objs
              #
        if ( !$package->{'Env'}->check_root() ) {
            $package->{'Io'}->print_alert(
                "Insufficient permission, something can go really wrong");
            $package->{'Io'}->set_debug(1);    #If no root given, debug on
        }

        return $package;
    }

    sub sighandler() {
        my $self = shift;
        $self->{'ModuleLoader'}->execute_on_all("clear");
        exit;
    }

}

1;

