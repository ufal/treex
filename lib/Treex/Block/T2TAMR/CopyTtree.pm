package Treex::Block::T2TAMR::CopyTtree;
use Moose;
use Treex::Core::Common;
use Treex::Block::T2TAMR::ApplyRules;
extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );
has '+selector'       => ( default => 'amrClonedFromT' );
has 'source_language' => ( is       => 'rw', isa => 'Str', lazy_build => 1 );
has 'source_selector' => ( is       => 'rw', isa => 'Str', default => '' );
has 'modifier_source' => ( is => 'ro', 'isa' => 'Str', default => 'functor' );

# TODO: copy attributes in a cleverer way
my @ATTRS_TO_COPY = qw(ord is_member);

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

    my %used_vars;

    my $source_zone = $bundle->get_zone( $self->source_language, $self->source_selector );
    my $source_root = $source_zone->get_ttree;

    my $target_zone = $bundle->get_or_create_zone( $self->language, $self->selector );
    my $target_root = $target_zone->create_ttree( { overwrite => 1 } );
    $target_root->set_attr( 'atree.rf', undef );

    $self->copy_subtree( $source_root, $target_root, \%used_vars );
    $target_root->set_src_tnode($source_root);
    
    # coreference is not copied here, FixCoreference should be used.
}

sub copy_subtree {
    my ( $self, $source_root, $target_root, $used_vars ) = @_;

    foreach my $source_node ( $source_root->get_children( { ordered => 1 } ) ) {
        my $target_node = $target_root->create_child();

        # copying attributes
        foreach my $attr (@ATTRS_TO_COPY) {
            $target_node->set_attr( $attr, $source_node->get_attr($attr) );
        }
        # copying the modifier labels from functors or formemes
        $target_node->wild->{modifier} = $self->modifier_source eq 'formeme' ? $source_node->formeme : $source_node->functor;

        # creating AMR-style lemma
        $target_node->set_t_lemma( _create_amr_lemma($source_node->t_lemma, $used_vars) );
        $target_node->set_src_tnode($source_node);
        $target_node->set_t_lemma_origin('t2tamr');

        # creating the 

        $self->copy_subtree( $source_node, $target_node, $used_vars );
    }
}

sub _create_amr_lemma {
    my ( $t_lemma, $used_vars ) = @_;

    my $var_letter = Treex::Block::T2TAMR::ApplyRules::firstletter($t_lemma);
    my $var_no = $used_vars->{$var_letter} // 0;
    $var_no++;
    $used_vars->{$var_letter} = $var_no;
    return $var_letter . ($var_no > 1 ? $var_no : '') . '/' . $t_lemma;
}



1;

=head1 NAME

Treex::Block::T2TAMR::CopyTtree

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
