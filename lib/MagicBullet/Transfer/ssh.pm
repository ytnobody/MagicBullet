package MagicBullet::Transfer::ssh;

use strict;
use warnings;

sub new {
    my ( $class, $src, $dest ) = @_;
    my %opts = ( src => $src, dest => $dest );
    return bless \%opts, $class;
}

sub transfer {
    my ( $self, $dry ) = @_;
    print $dry ? "### DRYMODE: sync to destination\n" : "### sync to destination\n" ;
    my @options = $dry ? 
        qw[ -azvun --delete --exclude .git ] :
        qw[ -azvu --delete --exclude .git ]
    ;
    my ( $dest_str, $dest_port ) = $self->dest_param;
    $self->rsync( 
        @options, $dest_port,
        $self->{src}->path, 
        $dest_str,
        $dry
    );
}

sub dest_param {
    my ( $self ) = @_;
    my $dest = $self->{dest};
    my $user = $dest->user || $ENV{USER};
    my $port = $dest->port || 22;
    my $port_opt = sprintf( "-e 'ssh -p %s'", $port ); 
    return ( sprintf( '%s@%s:%s', $user, $dest->host, $dest->path ), $port_opt );
}

sub rsync {
    my $self = shift;
    my @commands = ( grep { $_ if defined $_ } qw[ /usr/bin/env rsync ], @_ );
    print join ' ', "### Execute command:", @commands, "\n";
    map { print $_ } `@commands`;
}

1;
