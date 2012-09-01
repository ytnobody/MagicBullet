package MagicBullet::RemoteShell::ssh;
use strict;
use warnings;
use parent 'Net::SSH::Perl';
use Carp;

sub new {
    my ( $class, $uri ) = @_;
    my $self = $class->SUPER::new( 
        $uri->host, 
        identity_files => [
            "$ENV{HOME}/.ssh/identity",
            "$ENV{HOME}/.ssh/id_dsa",
            "$ENV{HOME}/.ssh/id_rsa",
        ],
        options => [
            "BatchMode yes", 
            "RHostAuthentication no"
        ] 
    );
    $self->{__URI} = $uri;
    my $user = $uri->user || $ENV{USER};
    $self->login;
    return $self;
}

sub login {
    my $self = shift;
    my $uri = $self->uri;
    my $user = $uri->user;
    return $uri->password ? 
        $self->SUPER::login( $user, $uri->password ) : 
        $self->SUPER::login( $user ) 
    ;
}

sub uri {
    return shift->{__URI};
}

sub cmd {
    my $self = @_;
    my $command = join '&&', @_;
    my $uri = $self->uri;
    my ( $stdout, $stderr, $status ) = $self->SUPER::cmd( sprintf('cd %s; %s'), $uri->path, $command );
    print $stdout if $stdout;
    unless ( $status == 0 ) {
        print $stderr if $stderr;
        Carp::carp( sprintf( "Failure on %s. exit code : %d", $uri->as_string, $status ) );
    }
    return $status;
}

1;
