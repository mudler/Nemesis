package Nemesis::IO;
use warnings;
use Term::UI;    #VOGLIO PASSARE A IO LA FUNZIONE di term::readline
use Term::ANSIColor;
use Carp qw( croak );

sub new {
    my $package = shift;
    bless( {}, $package );
    my (%config) = @_;
    %{ $package->{'CONFIG'} } = %config;

    #open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
    #open STDOUT, '>>/dev/null';
    open STDERR, \&debug();
    umask 0;
    return $package;
}

sub get_completion_color {

    return colored( '->', 'cyan bold on_black' );

}

sub get_prompt_out {

    return
          colored( "Nemesis", "green on_black" )
        . colored( "~",  "white on_black" )
        . colored( "# ", "blue on_black blink" );

}

sub print_ascii {
    my $self  = shift;
    my $FILE  = $_[0];
    my $COLOR = $_[1];

    open( my $fh, "<" . $FILE ) or croak("Can't open $FILE");

    while ( my $line = <$fh> ) {
        print colored( $line, $COLOR );
    }

    close $fh;

}

sub set_public_methods() {
    my $self = shift;
    $self->{'PUBLIC_METHOD'} = @_;

}

sub print_alert() {
    my $self = shift;
    print colored( "[",    "magenta on_black bold" )
        . colored( "Warn", "green on_black bold" )
        . colored( "]\t",  "magenta on_black bold" )
        . colored( $_[0],  "cyan on_black" ) . "\n";
}

sub print_verbose() {

    my $self = shift;
    my $text = $_[0];
    if ( $self->{'CONFIG'}->{'verbose'} == 1 ) {
        print "[! Nemesis Verbose !]\t" . $text . "\n";
    }
}

sub debug() {
    my $self = shift;
    if ( $self->{'CONFIG'}->{'debug'} == 1 ) {
        print colored( "[",     "magenta on_black bold" )
            . colored( "Debug", "white on_black bold" )
            . colored( "]",     "magenta on_black bold" )
            . colored( " (",    "magenta on_black bold" )
            . colored( $self->{'CONFIG'}->{'env'}->time_seconds(),
            "bold on_black white" )
            . colored( ") ",  "magenta on_black bold" )
            . colored( $_[0], "white on_black bold" ) . "\n";

    }
}

sub print_info() {
    my $self = shift;

    print colored( "[",  "magenta on_black bold" )
        . colored( "**", "green on_black bold" )
        . colored( "]",  "magenta on_black bold" )
        . colored( " (", "magenta on_black bold" )
        . colored( $self->{'CONFIG'}->{'env'}->time_seconds(),
        "bold on_black cyan" )
        . colored( ") ",  "magenta on_black bold" )
        . colored( $_[0], "blue on_black bold" ) . "\n";
}

sub print_error() {
    my $self = shift;

    print colored( "[",   "magenta on_black bold" )
        . colored( "Err", "red on_black bold" )
        . colored( "]",   "magenta on_black bold" )
        . colored( " (",  "magenta on_black bold" )
        . colored( $self->{'CONFIG'}->{'env'}->time_seconds(),
        "bold on_black red" )
        . colored( ") ",  "magenta on_black bold" )
        . colored( $_[0], "red on_black" ) . "\n";

}

sub print_tabbed {
    my $self = shift;
    $num = $_[1] || 1;
    print( colored( ( "\t" x $num ) . "~> ", "green on_black bold" ),
        colored( $_[0], "blue on_black bold" ), "\n" );

}

sub print_title {
    my $self = shift;
    my ($msg) = @_;
    printf "\n" . colored( $msg, "yellow on_black bold" ) . "\n";
    printf colored( "=" x length($msg), "white on_yellow" );
    printf "\n\n";
}

sub process_status {
    my $self    = shift;
    my $Process = $_[0];
    $self->print_info( $Process->get_var("code") );
    if ( $Process->is_running() ) {
        my $pid = $Process->get_pid();
        if ( !$pid ) {
            $pid = "n/a";
        }
        $self->print_tabbed( "PID:\t " . $pid, 1 );
        if ( $Process->get_var('file') ) {
            $self->print_tabbed(
                "Output (STDOUT):\t " . $Process->get_var('file'), 1 );
        }
        if ( $Process->get_var('file_log') ) {
            $self->print_tabbed(
                "Output (Log):\t " . $Process->get_var('file_log'), 1 );
        }
        if ( $Process->is_running() ) {
            $self->print_tabbed( "RUNNING", 1 );
        }

    }
    else {
        $self->print_tabbed( "NOT RUNNING", 1 );

    }

}

sub shell() {

    #qui invece aprirà una shell

}

sub exec() {
    my $self    = shift;
    my $command = $_[0];
    my $env     = $self->{'CONFIG'}->{'env'};
    my @output;
    my @path = $env->path();
    my @commands;
    my $final;
    if ( $command =~ /;/ ) {
        @commands = split( /;/, $command );
        foreach my $comm (@commands) {
            $final .= $self->generate_command($comm);
            $final .= ";";
        }
    }
    else {

        $final = $self->generate_command($command);
    }

    my $cwd = $env->workspace();
    @output = `cd $cwd;$final`;
    chomp(@output);
    return @output;

}

sub verbose() {
    my $self = shift;
    $self->print_info( "Verbose mode " . $_[0] );
    $self->{'CONFIG'}->{'verbose'} = $_[0];

}

sub set_debug() {
    my $self = shift;
    $self->print_info( "Debug mode " . $_[0] );
    $self->{'CONFIG'}->{'debug'} = $_[0];

}

sub generate_command() {
    my $self    = shift;
    my $command = $_[0];
    my $env     = $self->{'CONFIG'}->{'env'};
    my @path    = $env->path();

    if ( $command =~ / / ) {

        my @tmp_c = split( / /, $command );

        my $pp;

        #foreach my $tmp (@tmp_c) {
        $tmp = shift(@tmp_c);
        foreach my $p (@path) {
            $pp = $p;
            if ( -e "$p/$tmp" && $tmp !~ /\// )
            { #serve per ritrovare il programma di lancio e aggiungergli la path assoluta davanti
                if ( $pp =~ /\/$/ && $tmp =~ /^\// ) {
                    chop($pp);
                }
                $tmp = $pp . '/' . $tmp;
            }
        }

        #}
        $command = $tmp . " @tmp_c";
    }
    else {
        my $stop = 0;
        foreach my $p (@path) {
            next if $stop == 1;
            $pp = $p;
            if ( -e "$p/$command" && $command !~ /\// )
            { #serve per ritrovare il programma di lancio e aggiungergli la path assoluta davanti
                if ( $pp =~ /\/$/ && $command =~ /^\// ) {
                    chop($pp);
                }
                $command = $pp . '/' . $command;
                $stop    = 1;
            }
        }
    }

    return $command;
}

1;
__END__