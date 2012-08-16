package MagicBullet::Command;
use strict;
use warnings;
use parent qw( Class::Accessor::Fast );
use Carp;
use Getopt::Long;
use MagicBullet;
use MagicBullet::Config;
our $VERSION = '0.01';

__PACKAGE__->mk_accessors( qw( workdir reposdir metafile dest repo meta guard dry force ) );

sub bootstrap {
    my $class = shift;
    my ( $dest, $workdir, $repo, $dry, $force, $config );
    Carp::croak("could not get options") unless GetOptions(
        "dest=s@" => \$dest,
        "workdir=s" => \$workdir,
        "repo=s" => \$repo,
        "dry" => \$dry,
        "force" => \$force,
        "config=s" => \$config
    );
    my %conf = ( 
        dest => $dest,
        workdir => $workdir,
        repo => $repo,
        dry => $dry,
        force => $force,
        config($config),
    );
    return MagicBullet->new( %conf );
}

1;
