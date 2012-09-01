package MagicBullet::RemoteShell;
use strict;
use warnings;
use Class::Load ':all';

sub new {
    my ( $class, $uri ) = @_;
    my $klass = join '::', $class, $uri->scheme; 
    load_class( $klass ) unless is_class_loaded( $klass );
    return $klass->new( $uri );
}

1;
