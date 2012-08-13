package MagicBullet;
use strict;
use warnings;
use parent qw( Class::Accessor::Fast );
use Path::Class;
use Git::Class;
use Git::Class::Worktree;
use Getopt::Long;
use Digest::MD5;
use Carp;
use Guard ();
use Data::Dumper::Concise;
use Net::SSH::Perl;
use MagicBullet::Destination;
our $VERSION = '0.01';

__PACKAGE__->mk_accessors( qw( workdir reposdir metafile dest repo meta guard dry force ) );

sub bootstrap {
    my $class = shift;
    my $dest;
    my $workdir;
    my $repo;
    my $dry;
    my $force;
    unless ( GetOptions(
        "dest=s@" => \$dest,
        "workdir=s" => \$workdir,
        "repo=s" => \$repo,
        "dry" => \$dry,
        "force" => \$force,
    ) ){
        Carp::croak("could not get options ".$!);
    }
    unless ( $dest ) {
        Carp::croak("you must specify 1 or more destination");
    }
    unless ( $repo ) {
        Carp::croak("you must specify repository");
    }
    my $self = $class->new( 
        workdir => $workdir, 
        repo    => $repo, 
        dest    => $dest, 
        dry     => $dry, 
        force   => $force 
    );
    $self->clone;
    return $self;
}

sub new {
    my ( $class, %opts ) = @_;
    $opts{ workdir } ||= dir( $ENV{HOME}, '.magic_bullet' );

    my $self = $class->SUPER::new( \%opts );

    $self->dest( [ 
        map { MagicBullet::Destination->new($_) } @{$self->dest}
    ] );

    unless( ref ( $self->workdir ) eq 'Path::Class::Dir' ) {
        $self->workdir( dir( $self->workdir ) );
    }
    $self->workdir->mkpath( 1, 0755 );

    $self->reposdir( $self->workdir->subdir( 'repos' ) ); 
    $self->reposdir->mkpath( 1, 0755 );

    $self->metafile( $self->workdir->file( 'meta.pl' ) );
    unless ( -e $self->metafile->stringify ) {
        $self->metafile->spew( '{};' );
    }

    $self->meta( do($self->metafile->stringify) );

    my $metafile = $self->metafile;
    my $meta = $self->meta;
    my $guard = Guard::guard {
        $metafile->spew( Dumper( $meta ) );
    };
    $self->guard( $guard );

    return $self;
}

sub clone {
    my $self = shift;
    my $worktree = $self->worktree;

    unless ( $self->current_commit ) {
        $self->current_commit( (($worktree->show('HEAD'))[0] =~ /^commit (.+)$/)[0] );
    }
    else {
        $self->current_commit( (($worktree->show('HEAD'))[0] =~ /^commit (.+)$/)[0] );
        $worktree->pull;
        $self->current_commit( (($worktree->show('HEAD'))[0] =~ /^commit (.+)$/)[0] );
    }
}

sub sync {
    my $self = shift;
    my $current = $self->current_commit;
    for my $dest ( @{$self->dest} ) {
        my $remote = $self->remote_commit( $dest->stringify );
        $self->show_logs( $dest->stringify );
        unless ( $remote ) {
            unless ( $self->dry ) {
                print "### make destination directory\n";
                my $ssh = $self->ssh( $dest->host );
                if ( $ssh->login( $dest->account ) ) {
                    $ssh->cmd( sprintf("mkdir -pv %s", $dest->path) );
                }
            }
            else {
                print "### DRYMODE: make destination directory\n";
            }
        }
        unless ( $remote eq $current && !$self->force ) {
            print $self->dry ? 
                "### DRYMODE: sync to destination\n" :
                "### sync to destination\n"
            ;
            my @options = $self->dry ? 
                qw[ -azvun --delete --exclude .git ] :
                qw[ -azvu --delete --exclude .git ]
            ;
            $self->rsync( 
                @options,
                $self->local_repo->stringify.'/', 
                $dest->stringify,
            );
            if ( !$self->dry || $self->force ) { 
                $self->post_sync( $dest );
                $self->remote_commit( $dest->stringify, $current );
            }
        }
    }
}

sub post_sync {
    my ( $self, $dest ) = @_;
    my $post_sync_script = $self->local_repo->file( 'postsync.sh' )->stringify;
    if ( -x $post_sync_script ) {
        printf "### %s\@%s: Run postsync script\n", $dest->account, $dest->host;
        my $ssh = $self->ssh( $dest->host );
        if ( $ssh->login( $dest->account ) ) {
            print "connected\n";
            my ( $stdout, $stderr, $exit ) = $ssh->cmd( sprintf( "cd %s && ./postsync.sh", $dest->path ) );
            print $stdout if $stdout;
            print $stderr if $stderr;
            unless ( $exit == 0 ) {
                Carp::confess( "Failure to exec postsync.sh on %s. account: %s exit code : %d", $dest->host, $dest->account, $exit );
            }
        }
    }
}

sub worktree {
    my $self = shift;
    my $local_repo = $self->local_repo;
    return -r $local_repo ? 
        Git::Class::Worktree->new( path => $local_repo->stringify ):
        Git::Class->new->clone( $self->repo, $local_repo->stringify )
    ;
}

sub current_commit {
    my ( $self, $val ) = @_;
    if ( $val ) {
        $self->meta->{ $self->repo }->{ current } = $val;
    }
    return $self->meta->{ $self->repo }->{ current };
}

sub remote_commit {
    my ( $self, $dest, $val ) = @_;
    if ( $val ) {
        $self->meta->{ $self->repo }->{ $dest } = $val;
    }
    return $self->meta->{ $self->repo }->{ $dest } || '';
}

sub local_repo {
    my $self = shift;
    return $self->reposdir->subdir( Digest::MD5::md5_hex( $self->repo ) );
}

sub show_logs {
    my ( $self, $dest ) = @_;
    my $current = $self->current_commit;
    my $remote = $self->remote_commit( $dest );
    return if $remote eq $current;
    my $rev_diff = $remote ? join('..', $remote, $current) : undef ;
    if ( $rev_diff ) {
        printf "### %s\n", $rev_diff;
    }
    else {
        printf "### First Deploy (Revision: %s)\n", $current;
    }
    map { print "$_\n" } $rev_diff ? $self->worktree->log( $rev_diff ) : $self->worktree->log;
}

sub rsync {
    my $self = shift;
    my @commands = ( qw[ /usr/bin/env rsync ], @_ );
    print join ' ', "### Execute command:", @commands, "\n";
    map { print $_ } `@commands`;
}

sub ssh {
    my ( $self, $host ) = @_;
    return Net::SSH::Perl->new( $host, 
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
}

1;
__END__

=head1 NAME

MagicBullet -

=head1 SYNOPSIS

  use MagicBullet;

=head1 DESCRIPTION

MagicBullet is

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
