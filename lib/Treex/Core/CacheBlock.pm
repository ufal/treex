package Treex::Core::CacheBlock;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Digest::MD5 qw(md5_hex);
use Storable;
use Time::HiRes;
use App::whichpm 'which_pm';
use Treex::Tool::Memcached::Memcached;

extends 'Treex::Core::Block';

#TODO: params could be obtained directly from block

has block => ( is => 'ro', isa => 'Treex::Core::Block' );
has params => (is => 'ro', isa => 'HashRef');


has _block_hash => (is => 'rw', isa => 'Str');
has _memcached => (is => 'rw', isa => 'Cache::Memcached');
has _loaded => (is => 'rw', isa => 'Bool', default => 0);

sub BUILD {
    my $self = shift;

    my $md5 = Digest::MD5->new();

    # compute block parameters hash
    my $params_str = "";
    map { $params_str .= $_ ."=".$self->params->{$_}; }
        sort grep { ! /scenario/ }
        keys %{$self->params};
    $md5->add($params_str);

    # compute block source code hash
    my ($block_filename, $block_version) = which_pm($self->block->get_block_name());
    open(my $block_fh, "<", $block_filename) or log_fatal("Can't open '$block_filename': $!");
    binmode($block_fh);
    $md5->addfile($block_fh);
    close($block_fh);
    $self->_set_block_hash($md5->hexdigest);

    return;
}

sub process_document {
    my $self = shift;

    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    $Storable::canonical = 1;


    my $document_hash = md5_hex(Storable::freeze($document));
    log_info("CACHE: document_hash\t$document_hash");

    my $full_hash = $self->_block_hash . $document_hash;
    my $cached_document = $self->_memcached->get($full_hash);

    if ( ! $cached_document ) {
        if ( ! $self->_loaded() ) {
            $self->block->process_start();
            $self->_set_loaded(1);
        }
        log_info("CACHE: calling process_document " . $self->block->get_block_name());
        $self->block->process_document(@_);
        $self->_memcached->set($full_hash, \@_);
    } else {
        log_info("CACHE: loading from cache " . $self->block->get_block_name());
        for my $i (0 .. $#{$cached_document}) {
            $_[$i] = $cached_document->[$i];
        }
    }
    $Storable::canonical = 0;

    return 1;
}

sub get_required_share_files {
    my ($self) = @_;

    return $self->block->get_required_share_files();
}


sub process_start {
    my $self = shift;
    $self->_set_memcached(
        Treex::Tool::Memcached::Memcached::get_connection(
            $self->block->get_block_name()
        )
    );

    return;
}

sub process_end {
    my ($self) = @_;
    $self->block->process_end();
    # default implementation is empty, but can be overriden
    return;
}

sub get_block_name {
    my $self = shift;
    if ( ! defined($self->block) ) {
        return ref($self);
    } else {
        return $self->block->get_block_name() . " with cache";
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::CacheBlock - Treex::Core::Block with caching

=head1 SYNOPSIS

 package Treex::Block::My::Block;
 use Moose;
 use Treex::Core::Common;
 extends 'Treex::Core::Block';

 sub process_bundle {
    my ( $self, $bundle) = @_;

    # bundle processing

 }

=head1 DESCRIPTION

C<Treex::Core::CacheBlock> is a decorator for any C<Treex::Core::Block>
which provides transparen caching.

=head1 SEE ALSO

L<Treex::Core::Block>,

=head1 AUTHOR

Martin Majlis <majlis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
