package MagicBullet::Destination;
use strict;
use warnings;
use Data::Dumper;

sub new {
    my ( $class, $str ) = @_;
    my @parts = $str =~ /^(.*@)?(.+?):(.+)$/;
    unless ( $parts[0] ) {
        $parts[0] = $ENV{USER};
    }
    $parts[0] =~ s[@][];
    return bless \@parts, $class;
}

sub stringify {
    my $self = shift;
    return sprintf( '%s@%s:%s', @{$self} );
}

sub account {
    my $self = shift;
    return $self->[0];
}

sub host {
    my $self = shift;
    return $self->[1];
}

sub path {
    my $self = shift;
    return $self->[2];
}

1;
