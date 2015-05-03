package Treex::Block::T2T::CopyTtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );

# TODO: copy attributes in a cleverer way
my @ATTRS_TO_COPY = qw(ord t_lemma functor formeme is_member nodetype is_generated subfunctor
    is_name_of_person is_clause_head is_relclause_head is_dsp_root is_passive is_parenthesis is_reflexive
    voice sentmod tfa gram/sempos gram/gender gram/number gram/degcmp
    gram/verbmod gram/deontmod gram/tense gram/aspect gram/resultative
    gram/dispmod gram/iterativeness gram/indeftype gram/person gram/numertype
    gram/politeness gram/negation gram/definiteness gram/diathesis clause_number);

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

sub process_document {
    my ( $self, $document ) = @_;

    # the forward links (from source to target nodes) must be kept so that coreference links are copied properly
    my %src2tgt;

    foreach my $bundle ( $document->get_bundles() ) {
        my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
        my $source_root = $source_zone->get_ttree;

        my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );
        my $target_root = $target_zone->create_ttree( { overwrite => 1 } );
        $target_root->set_attr( 'atree.rf', undef );

        copy_subtree( $source_root, $target_root, \%src2tgt );
        $target_root->set_src_tnode($source_root);
    }

    # copying coreference links
    foreach my $bundle ( $document->get_bundles() ) {
        my $target_zone = $bundle->get_zone( $self->language, $self->selector );
        my $target_root = $target_zone->get_ttree();
        foreach my $t_node ( $target_root->get_descendants ) {
            my $src_tnode  = $t_node->src_tnode;
            my $coref_gram = $src_tnode->get_deref_attr('coref_gram.rf');
            my $coref_text = $src_tnode->get_deref_attr('coref_text.rf');
            if ( defined $coref_gram ) {
                my @nodelist = map { $src2tgt{$_} } @$coref_gram;
                $t_node->set_deref_attr( 'coref_gram.rf', \@nodelist );
            }
            if ( defined $coref_text ) {
                my @nodelist = map { $src2tgt{$_} } @$coref_text;
                $t_node->set_deref_attr( 'coref_text.rf', \@nodelist );
            }
        }
    }
}

sub copy_subtree {
    my ( $source_root, $target_root, $src2tgt ) = @_;

    foreach my $source_node ( $source_root->get_children( { ordered => 1 } ) ) {
        my $target_node = $target_root->create_child();

        $$src2tgt{$source_node} = $target_node;

        # copying attributes
        # TODO: this must be done in another way
        foreach my $attr (@ATTRS_TO_COPY) {
            $target_node->set_attr( $attr, $source_node->get_attr($attr) );
        }
        $target_node->set_src_tnode($source_node);
        $target_node->set_t_lemma_origin('clone');
        $target_node->set_formeme_origin('clone');

        copy_subtree( $source_node, $target_node, $src2tgt );
    }
}

1;

=over

=item Treex::Block::T2T::CopyTtree

This block copies tectogrammatical tree into another zone.
Attributes 'a/lex.rf' and 'a/aux.rf' are not copied within the nodes.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
