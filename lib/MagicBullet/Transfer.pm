package MagicBullet::Transfer;
use strict;
use warnings;
use parent 'MagicBullet::ProxyBase';

sub new {
    my ( $class, $src, $dest ) = @_;
    my $self = $class->SUPER::new( $dest );
    $self->{dest} = $self->{src};
    $self->{src} = $src;
    return $self;
}

1;
