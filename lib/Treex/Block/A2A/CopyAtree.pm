package Treex::Block::A2A::CopyAtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

# TODO: copy attributes in a cleverer way
my @ATTRS_TO_COPY = qw(form tag lemma ord afun deprel is_member no_space_after);

sub _build_source_selector {
    my ($self) = @_;
    return $self->selector;
}

sub _build_source_language {
    my ($self) = @_;
    return $self->language;
}

sub BUILD {
    my ($self) = @_;
    if ( $self->language eq $self->source_language && $self->selector eq $self->source_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
    my $source_root = $source_zone->get_atree;

    my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );
    my $target_root = $target_zone->create_atree();
    
    copy_subtree( $source_root, $target_root );
}

sub copy_subtree {
    my ( $source_root, $target_root ) = @_;

    foreach my $source_node ( $source_root->get_children( { ordered => 1 } ) ) {
        my $target_node = $target_root->create_child();

        # copying attributes
        # TODO: this must be done in another way
        foreach my $attr (@ATTRS_TO_COPY) {
            $target_node->set_attr( $attr, $source_node->get_attr($attr) );
        }
        copy_subtree( $source_node, $target_node );
    }
}

1;

=over

=item Treex::Block::A2A::CopyAtree

This block copies analytical tree into another zone.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
