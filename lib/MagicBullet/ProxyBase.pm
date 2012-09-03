package MagicBullet::ProxyBase;
use strict;
use warnings;
use Class::Load ':all';
use Carp;

sub new {
    my ( $class, $uri ) = @_;
    Carp::confess 'specified uri is not URI object' unless $uri->isa('URI');
    Carp::confess 'undefined scheme' unless $uri->scheme;
    my $klass = join '::', $class, $uri->scheme; 
    load_class( $klass ) unless is_class_loaded( $klass );
    return $klass->new( $uri );
}

1;
