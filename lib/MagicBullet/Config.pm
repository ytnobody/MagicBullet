package MagicBullet::Config;
use strict;
use warnings;
use Exporter 'import';
use JSON;
use YAML;
use Path::Class;
use File::Find;

our @EXPORT = qw( config );

sub config {
    my @files = $_[0] ? $_[0] : undef;
    find( sub { push @files, $File::Find::name if $_ =~ /^magicbullet\./  }, '.' );
    for my $entry ( @files ) {
        my $file = file( $entry );
        if ( -e $file->stringify ) {
            my $config;
            for my $format ( qw[ as_yaml as_json as_perl ] ) {
                no strict qw[subs refs]; ## no critic
                $config = eval { &{"MagicBullet::Config::$format"}( $file ) };
                return %$config if $config;
            }
        }
    }
    return ();
}

sub as_yaml {
    my $file = shift;
    return YAML::LoadFile( $file->stringify );
}

sub as_json {
    my $file = shift;
    my $data = join '', $file->slurp;
    return JSON->new->utf8->decode( $data );
}

sub as_perl {
    my $file = shift;
    return do( $file->stringify );
}

1;
