package Treex::Block::Align::T::AlignGeneratedNodes;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;
extends 'Treex::Core::Block';

has 'to_language' => (
    is         => 'ro',
    isa        => 'Treex::Type::LangCode',
    lazy_build => 1,
);

has 'to_selector' => (
    is      => 'ro',
    isa     => 'Treex::Type::Selector',
    default => 'trg',
);

sub _build_to_language {
    my ($self) = @_;
    return $self->language;
}

has '+language' => ( required => 1 );

sub BUILD {
    my ($self) = @_;
#    log_info( $self->language );
    if ( $self->language eq $self->to_language && $self->selector eq $self->to_selector ) {
        log_fatal("Can't create zone with the same 'language' and 'selector'.");
    }
}


sub process_zone {
    my ( $self, $ref_zone ) = @_;
    
    my $auto_zone = $ref_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @auto_nodes = grep {$_->is_generated} $auto_zone->get_ttree->get_descendants( { ordered => 1 } );
    my @ref_nodes = grep {$_->is_generated} $ref_zone->get_ttree->get_descendants( { ordered => 1 } );
    return if @auto_nodes == 0;
    my $auto_free = { map { $_->id => $_ } @auto_nodes };
    my $ref_free = { map { $_->id => $_ } @ref_nodes };

    $self->align_generated_nodes_by_tlemma_functor_parent($auto_free, $ref_free);
    $self->align_generated_nodes_by_functor_parent($auto_free);
}

sub _get_related_verbs_via_alayer {
    my ($auto_node) = @_;

    ###### WARNING: this is language and tagset dependent #############
    my @auto_aaux = grep {$_->tag =~ /^V/} $auto_node->get_aux_anodes;
    my @ref_aaux = Treex::Tool::Align::Utils::aligned_transitively([@auto_aaux], [{rel_types => ['monolingual']}]);
    my @ref_nodes = ();
    push @ref_nodes, map {$_->get_referencing_nodes('a/lex.rf')} @ref_aaux;
    push @ref_nodes, map {$_->get_referencing_nodes('a/aux.rf')} @ref_aaux;
    return @ref_nodes;
}

sub align_generated_nodes_by_tlemma_functor_parent {
    my ($self, $auto_free, $ref_free) = @_;

    foreach my $auto_node (values %$auto_free) {
        my @auto_epars = $auto_node->get_eparents;
        my @ref_epars = Treex::Tool::Align::Utils::aligned_transitively([@auto_epars], [{rel_types => ['monolingual']}]);
        push @ref_epars, map {_get_related_verbs_via_alayer($_)} @auto_epars;
        my %processed = ();
        my $ref_node;
        foreach my $ref_epar (@ref_epars) {
            next if ($processed{$ref_epar->id});
            $processed{$ref_epar->id}++;
            my @functor_kids = grep {$_->functor eq $auto_node->functor} $ref_epar->get_echildren;
            # following ensures that the ref node is generated with one of the 3 t_lemmas as well as not yet covered
            ($ref_node) = grep { $_->t_lemma =~ /^(\#PersPron)|(\#Cor)|(\#Gen)$/ && $ref_free->{$_->id} } @functor_kids;
            last if ($ref_node);
        }
        
        if ($ref_node) {
            $ref_node->add_aligned_node( $auto_node, 'monolingual' );
            delete $auto_free->{$auto_node->id};
        }
    }
}

sub align_generated_nodes_by_functor_parent {
    my ($self, $auto_free ) = @_;

    foreach my $auto_node (values %$auto_free) {
        my $auto_par = $auto_node->get_parent;
        next if (!$auto_par);
        my ($ref_par) = Treex::Tool::Align::Utils::aligned_transitively([$auto_par], [{rel_types => ['monolingual']}]);
        next if (!$ref_par);
        my ($ref_eq) = grep {$_->functor eq $auto_node->functor} $ref_par->get_echildren;
        next if (!$ref_eq);
        my ($auto_eq) = Treex::Tool::Align::Utils::aligned_transitively([$ref_eq], [{rel_types => ['monolingual']}]);
        next if (!$auto_eq);
        next if ($auto_eq->clause_number == $auto_node->clause_number);
        
        $ref_eq->add_aligned_node( $auto_node, 'monolingual.loose' );
        delete $auto_free->{$auto_node->id};
    }
}

1;

=head1 NAME

Treex::Block::Align::T::AlignGeneratedNodes

=head1 DESCRIPTION

A block for monolingual alignment of generated nodes, i.e. aligning
the generated nodes between gold and automatically analysed trees.
This block must be run on the zone with gold trees (usually "ref").

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
