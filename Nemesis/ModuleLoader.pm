package Nemesis::ModuleLoader;

use strict;
use Carp qw( croak );
use Storable qw(dclone freeze thaw);

#external modules

my $base = {
    'path'         => 'Plugin',
    'pwd'          => './',
    'main_modules' => 'Nemesis'
};

sub new {
    my $class = shift;
    my $self  = { 'Base' => $base };
    my (%Obj) = @_;
    %{ $self->{'core'} } = %Obj;
    die("IO and environment must be defined\n")
        if ( !defined( $self->{'core'}->{'IO'} )
        || !defined( $self->{'core'}->{'env'} ) );
    return bless $self, $class;
}

sub execute {
    my $self    = shift;
    my $module  = shift @_;
    my $command = shift @_;

    # my $object  = "$self->{'Base'}->{'path'}::$module";
    eval( "$self->{'Base'}->{'path'}::$module"->$command(@_) );
    if ($@) {
        $self->{'core'}->{'IO'}
            ->print_error("Something went wrong with $command: $@");
    }

}

sub execute_on_all {
    my $self    = shift;
    my $met     = shift @_;
    my @command = @_;
    foreach my $module ( sort( keys %{ $self->{'modules'} } ) ) {

        eval("$self->{'modules'}->{$module}->$met(@command)");
        if ($@) {
            $self->{'core'}->{'IO'}->print_error(
                "Something went wrong calling the method '$met' on '$module': $@"
            );
        }
    }

}

sub export_public_methods() {
    my $self = shift;
    my @OUT;
    my @PUBLIC_FUNC;
    foreach my $module ( sort( keys %{ $self->{'modules'} } ) ) {

        eval {

            @PUBLIC_FUNC = ();
            @PUBLIC_FUNC =
                $self->{'modules'}->{$module}->export_public_methods();
            foreach my $method (@PUBLIC_FUNC) {
                $method = $module . "." . $method;

            }
            push( @OUT, @PUBLIC_FUNC );

        }

    }
    return @OUT;

}

sub listmodules {
    my $self = shift;
    my $IO   = $self->{'core'}->{'IO'};
    $IO->print_title("List of modules");
    foreach my $module ( sort( keys %{ $self->{'modules'} } ) ) {
        $IO->print_info("$module");
        $self->{'modules'}->{$module}->info()
            ; #so i can call also configure() and another function to display avaible settings!
    }

}

sub loadmodule() {
    my $self   = shift;
    my $module = $_[0];
    my $IO     = $self->{'core'}->{'IO'};
    my $path   = $self->{'Base'}->{'pwd'} . $self->{'Base'}->{'path'};
    my $base;

    if ( -e $self->{'Base'}->{'path'} . "/" . $module . ".pm" ) {

        $base = $self->{'Base'}->{'path'};

    }
    elsif ( -e $self->{'Base'}->{'main_modules'} . "/" . $module . ".pm" ) {
        $base = $self->{'Base'}->{'main_modules'};

    }
    else {

        return ();

    }

    $IO->debug("Module $module found in $base");

    my $object = $base . "::" . $module;

    if (eval {

            $module =
                $object->new( %{ $self->{'core'} }, ModuleLoader => $self );

        }
        )
    {

        return $module;
    }
    else {

        $self->{'core'}->{'IO'}
            ->print_error("Something went wrong with $object: $@");

    }
    return ();
}

sub loadmodules {
    my $self = shift;
    my @modules;
    my $IO   = $self->{'core'}->{'IO'};
    my $path = $self->{'Base'}->{'pwd'} . $self->{'Base'}->{'path'};
    local *DIR;
    if ( !opendir( DIR, "$path" ) ) {
        return "[LOADMODULES] - (*) No such file or directory ($path)";
    }
    my @files = grep( !/^\.\.?$/, readdir(DIR) );
    closedir(DIR);

    my $modules;
    my $mods = 0;
    foreach my $f (@files) {
        my $base = $self->{'Base'}->{'path'} . "/" . $f;
        my ($name) = $f =~ m/([^\.]+)\.pm/;
        delete $INC{ $self->{'Base'}->{'path'} . "/" . $name };

        $IO->debug("Loading module: $base");
        my $result = do($base);

        if ($@) {
            $IO->print_error($@);
            delete $INC{ $self->{'Base'}->{'path'} . "/" . $name };
            next;
        }
        if ( !$result ) {
            $IO->print_error("module ($base) did not return true\n");
            next;
        }
        my $object = "$self->{'Base'}->{'path'}::$name";
        if (eval {
                $modules->{$name} = $object->new( %{ $self->{'core'} },
                    ModuleLoader => $self );
            }
            )
        {    #Verify object's creation
            $mods++;
        }
        else {
            $IO->print_error("Error: module ($base): $@");
        }

    }
    $IO->print_info("> $mods modules available. Double tab to see them\n");

    # delete $self->{'modules'};
    $self->{'modules'} = $modules;
    return 1;
}

1;