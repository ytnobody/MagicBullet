package MagicBullet::RemoteShell::ssh;
use strict;
use warnings;
use Net::SSH::Perl;
use Carp;

sub new {
    my ( $class, $uri ) = @_;
    my $ssh = Net::SSH::Perl->new( 
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
    my $self = bless {
        uri => $uri, 
        ssh => $ssh,
    }, $class;
    $self->login;
    return $self;
}

sub login {
    my $self = shift;
    my $uri = $self->uri;
    my $user = $uri->user || $ENV{USER};
    return $uri->password ? 
        $self->ssh->login( $user, $uri->password ) : 
        $self->ssh->login( $user ) 
    ;
}

sub uri { return shift->{uri} }

sub ssh { return shift->{ssh} }

sub cmd {
    my $self = shift;
    my $command = join '&&', @_;
    my $uri = $self->uri;
    my ( $stdout, $stderr, $status ) = $self->ssh->cmd( sprintf 'cd %s; %s', $uri->path, $command );
    print $stdout if $stdout;
    unless ( $status == 0 ) {
        print $stderr if $stderr;
        Carp::carp( sprintf( "Failure on %s. exit code : %d", $uri->as_string, $status ) );
    }
    return $status;
}

1;
