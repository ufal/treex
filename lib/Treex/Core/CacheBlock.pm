package Treex::Core::CacheBlock;

use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Digest::MD5 qw(md5_hex);
use Storable;
use Time::HiRes;
extends 'Treex::Core::Block';

#TODO: params could be obtained directly from block

has block => ( is => 'ro', isa => 'Treex::Core::Block' );

has cache => (is => 'ro', isa => 'Cache::Memcached');
has _loaded => (is => 'rw', isa => 'Bool', default => 0);

sub BUILD {
    my $self = shift;
    require Treex::Tool::Memcached::Memcached;

    return;
}

override 'get_hash' => sub {
    my $self = shift;
    return $self->block->get_hash();
};

sub process_document {
    my $self = shift;

    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    $Storable::canonical = 1;

#    $document->set_hash(md5_hex($document->get_hash() . $self->block->get_hash()));

#    my $document_hash = md5_hex(Storable::freeze($document));
#    log_info("CACHE: document_hash\t$document_hash");

    my $full_hash = $document->get_hash();
    my $cached_document = $self->cache->get($full_hash);

    my $return_code = $Treex::Core::Block::DOCUMENT_PROCESSED;

    if ( ! $cached_document ) {
        if ( ! $self->_loaded() ) {
            $self->block->process_start();
            $self->_set_loaded(1);
        }
        log_info("CACHE: calling process_document " . $self->block->get_block_name());
        $self->block->process_document($document);
        #my $str = Storable::nfreeze($document);
        #log_info("CACHE: Storing - $full_hash - $document - " . length($str) . "b");
        log_info("CACHE: Storing - $full_hash - $document");
        $self->cache->set($full_hash, $document);
#
#        my $tmp_doc = $self->cache->get($full_hash);
#        if ( ! $tmp_doc ) {
#            sleep(1);
#            log_info("CACHE: Storing - $full_hash - again!!");
#            log_info("SET: " . $self->cache->set($full_hash, $document));
#            log_info("ADD: " . $self->cache->add($full_hash, $document));
#            my $tmp_doc = $self->cache->get($full_hash);
#            if ( ! defined($tmp_doc) ) {
#                my $str = Storable::nfreeze($document);
#                log_warn("Document size: " . length($str));
#            }
#        }
#        log_fatal("AAAAAAAAAAAAA") if ! $tmp_doc;
    } else {
        log_info("CACHE: loading from cache " . $self->block->get_block_name());
        $_[0] = $cached_document;
        $return_code = $Treex::Core::Block::DOCUMENT_FROM_CACHE;
    }

    $Storable::canonical = 0;

    return $return_code;
}

sub get_required_share_files {
    my ($self) = @_;

    return $self->block->get_required_share_files();
}

sub process_end {
    my ($self) = @_;
    $self->block->process_end();
    # default implementation is empty, but can be overriden
    return;
}

override 'get_block_name' => sub {
    my $self = shift;
    if ( ! defined($self->block) ) {
        return ref($self);
    } else {
        return $self->block->get_block_name();
    }
};

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
