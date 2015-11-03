package Treex::Block::Read::BaseSplitterRole;
use strict;
use warnings;
use Moose::Role;
use MooseX::SemiAffordanceAccessor;

has bundles_per_doc => (
    isa => 'Int',
    is => 'ro',
    default => 0,
    documentation => 'Split the original file into more documents, each with max. N bundles. The deafult is 0 (do not split).',
);

has _buffer_doc => (is=> 'rw');

after 'BUILD' => sub {
    my ($self) = @_;
    if ( $self->bundles_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
};

around 'next_document' => sub {
    my ($orig_next_doc_method, $self, $filename) = @_;

    my $doc = $self->_buffer_doc;

    if (!$doc) {
        $doc = $self->$orig_next_doc_method($filename);
        return if !$doc;
    }

    if ($self->bundles_per_doc) {
        my $bundles_ref = $doc->treeList();
        if (  @$bundles_ref > $self->bundles_per_doc) {
            my $new_doc = $self->new_document();
            my @moving_bundles = splice @$bundles_ref, $self->bundles_per_doc;
            # TODO fix references (delete coreference links) going across new doc boundaries
            # or suggest to use block Util::FixInvalidIDs
            push @{$new_doc->treeList()}, @moving_bundles;
            $self->_set_buffer_doc($new_doc);
        } else {
            $self->_set_buffer_doc(undef);
        }
    }

    return $doc;
};

1;

__END__

=head1 NAME

Treex::Block::Read::BaseSplitterRole

=head1 DESCRIPTION

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
