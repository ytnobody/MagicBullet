package MagicBullet;
use strict;
use warnings;
use parent qw( Class::Accessor::Fast );
use Path::Class;
use Git::Class;
use Git::Class::Worktree;
use Digest::MD5;
use Carp;
use Guard ();
use Data::Dumper::Concise;
use Pod::Help qw( -h --help );
use URI;
use MagicBullet::RemoteShell;
use MagicBullet::Transfer;
our $VERSION = '0.01';

__PACKAGE__->mk_accessors( qw( workdir reposdir metafile dest repo meta guard dry force postsync ) );

sub as_array ($) {
    my $var = shift;
    return ref $var eq 'ARRAY' ? @$var : ( $var );
}

sub new {
    my ( $class, %opts ) = @_;

    unless ( $opts{repo} ) {
        Carp::carp("you must specify repository");
        Pod::Help->help( $class );
    }
    $opts{ workdir } ||= dir( $ENV{HOME}, '.magic_bullet' );

    my $self = $class->SUPER::new( \%opts );
    $self->dest( [map { URI->new($_) } as_array $self->dest] );
    $self->init_workdir;
    $self->load_metafile;

    return $self;
}

sub init_workdir {
    my $self = shift;

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
}

sub load_metafile {
    my $self = shift;
    $self->meta( do($self->metafile->stringify) );

    my $metafile = $self->metafile;
    my $meta = $self->meta;
    my $guard = Guard::guard {
        $metafile->spew( Dumper( $meta ) );
    };
    $self->guard( $guard );
}

sub clone_repo {
    my $self = shift;
    my $worktree = $self->worktree;

    my $update_current_commit = sub {
        my ( $self, $worktree ) = @_;
        $self->current_commit( (($worktree->show('HEAD'))[0] =~ /^commit (.+)$/)[0] );
    };

    if ( $self->current_commit ) {
        $update_current_commit->( $self, $worktree );
        $worktree->pull;
    }
    $update_current_commit->( $self, $worktree );
}

sub sync {
    my $self = shift;
    my $current = $self->current_commit;
    for my $dest ( as_array $self->dest ) {
        my $remote = $self->remote_commit( $dest->as_string );
        $self->show_logs( $dest->as_string );
        unless ( $remote ) {
            unless ( $self->dry ) {
                print "### make destination directory\n";
                if ( my $rsh = MagicBullet::RemoteShell->new( $dest ) ) {
                    $rsh->cmd( sprintf("mkdir -pv %s", $dest->path) );
                }
            }
            else {
                print "### DRYMODE: make destination directory\n";
            }
        }
        unless ( $remote eq $current && !$self->force ) {
            my $transfer = MagicBullet::Transfer->new( 
                 URI->new( 'file://'. $self->local_repo->stringify.'/', 'file'), 
                 $dest,
             );
            $transfer->transfer( $self->dry );
            if ( !$self->dry || $self->force ) { 
                $self->postsync_run( $dest );
                $self->remote_commit( $dest->as_string, $current );
            }
        }
    }
}

sub postsync_run {
    my ( $self, $dest ) = @_;
    my $post_sync_script = $self->local_repo->file( 'postsync.sh' )->stringify;
    if ( -x $post_sync_script || $self->postsync ) {
        printf "### %s\@%s: Begin postsync step\n", $dest->user, $dest->host;
        if (my $rsh = MagicBullet::RemoteShell->new($dest)) {
            my @cmdlist = 
                -x $post_sync_script ? './postsync.sh' :
                $self->postsync ? as_array $self->postsync :
            ();
            for my $cmd ( @cmdlist ) {
                print "$cmd\n";
                my $status = $rsh->cmd( $cmd );
                return if $status != 0;
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

1;
__END__

=head1 NAME

MagicBullet - Yet another deploy helper

=head1 SYNOPSIS

    $ magic-bullet \
        --repo=git://address.to/your/repository \
        --dest=ssh://account@your.dest.host/path/to/destination/ \
        ( --dry --force )
    
    ### or if you use config file,
    $ magic-bullet --config /path/to/config.json

=head1 DESCRIPTION

MagicBullet is deploy helper tool that aims be most minimalist in these tools.

=head1 REQUIRED SWITCHES

=head2 --repo [address_for_your_repository]

Specifier for your repository. 

=head2 --dest [account@hostname:path]

Specifier for destination account and host/path.

You may specify this option multiple. Look at followings.

    $ magic-bullet \
        --repo=git://foobar.com/myname/myrepo \
        --dest=ssh://account@dest1.your.host/path/to/dest \
        --dest=ssh://account@dest2.your.host/path/to/dest \
        --dest=ssh://account@dest3.your.host/path/to/dest

=head1 OPTIONAL SWITCHES

=head2 --dry

Show deploy process and exit (no change).

=head2 --force

Try to rsync force.

=head1 USING CONFIG FILE

You may specify configuration for deploy in ./magicbullet.(pl|yml|yaml|conf|json) 

You have to specify following attributes into configuration.

=over 4

=item repo (string)

URI for repository

=item dest (arrayref)

List of rsync destination.

=item postsync (arrayref/optional)

Command list for postsync step

=back

=head2 EXAMPLE OF CONFIG FILE

    ### magicbullet.yml
    ---
    repo: 'git://my.git.host/myname/MyRepo.git',
    dest:
      - 'ssh://user@www01.myserver/path/to/deploy/dest'
      - 'ssh://user@www02.myserver/path/to/deploy/dest'
      - 'ssh://user@www03.myserver/path/to/deploy/dest'
      - 'ssh://user@www04.myserver/path/to/deploy/dest'
    postsync:
      - 'cpanm --test-only ./ -l extlib -v'
      - 'svc -h /service/myapp'

=head1 ABOUT POST-SYNC SCRIPT

If ./postsync.sh is in your repository, MagicBullet execute it when files were synced.

=head1 AUTHOR

ytnobody E<lt>ytnobody@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
