package Treex::Block::Align::T::AlignGeneratedNodes;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Align::Utils;
extends 'Treex::Core::Block';

has 'monolingual' => ( is => 'ro', isa => 'Bool', default => 1 );

has 'to_language' => (
    is         => 'ro',
    isa        => 'Treex::Type::LangCode',
    lazy_build => 1,
);

has 'to_selector' => (
    is      => 'ro',
    isa     => 'Treex::Type::Selector',
    default => '',
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
    if ( $self->monolingual && $self->language ne $self->to_language ) {
        log_fatal("Can't create monolingual alignment between different languages.");
    }
}


sub process_zone {
    my ( $self, $from_zone ) = @_;
    
    my $to_zone = $from_zone->get_bundle()->get_zone( $self->to_language, $self->to_selector );
    my @to_nodes = grep {$_->is_generated} $to_zone->get_ttree->get_descendants( { ordered => 1 } );
    my @from_nodes = grep {$_->is_generated} $from_zone->get_ttree->get_descendants( { ordered => 1 } );
    return if @to_nodes == 0;
    my $to_free = { map { $_->id => $_ } @to_nodes };
    my $from_free = { map { $_->id => $_ } @from_nodes };

    $self->align_generated_nodes_by_tlemma_functor_parent($to_free, $from_free);
    if ($self->monolingual) {
        # loose monolingual alignments

        $self->align_generated_nodes_by_functor_parent($to_free);
        $self->align_arguments_of_nonfinites_to_grandparents($to_free);
        # align generated nodes on "ref" with their antecedents' counterparts in the "src" - gold coreference is used
        $self->align_generated_nodes_to_coref_ante_counterpart($from_free, 'forwards');
        # align generated nodes on "src" with their antecedents' counterparts in the "ref" - automatic coreference is used
        $self->align_generated_nodes_to_coref_ante_counterpart($to_free, 'backwards');
    }
}

sub _align_filter {
    my ($self, $direction) = @_;
    $direction //= 'forwards';
    my $align_filter = {
        language => $direction eq 'backwards' ? $self->language : $self->to_language,
        selector => $direction eq 'backwards' ? $self->selector : $self->to_selector,
    };
    if ($self->monolingual) {
        $align_filter->{rel_types} = ['^monolingual$'];
    }
    return $align_filter;
}

sub _align_name {
    my ($self, $strength) = @_;
    my $name = $self->monolingual ? 'monolingual' : 'rule-based';
    if (defined $strength) {
        $name .= ".$strength";
    }
    return $name;
}

sub _get_related_verbs_via_alayer {
    my ($self, $to_node) = @_;

    ###### WARNING: this is language and tagset dependent #############
    my @to_aaux = grep {$_->tag =~ /^V/} $to_node->get_aux_anodes;

    my @from_aaux = Treex::Tool::Align::Utils::aligned_transitively([@to_aaux], [ $self->_align_filter('backwards') ]);
    my @from_nodes = ();
    push @from_nodes, map {$_->get_referencing_nodes('a/lex.rf')} @from_aaux;
    push @from_nodes, map {$_->get_referencing_nodes('a/aux.rf')} @from_aaux;
    return @from_nodes;
}

sub align_generated_nodes_by_tlemma_functor_parent {
    my ($self, $to_free, $from_free) = @_;

    foreach my $to_node (values %$to_free) {
        my @to_epars = $to_node->get_eparents({or_topological => 1});
        my @from_epars = Treex::Tool::Align::Utils::aligned_transitively([@to_epars], [ $self->_align_filter('backwards') ]);
        push @from_epars, map {$self->_get_related_verbs_via_alayer($_)} @to_epars;
        my %processed = ();
        my $from_node;
        foreach my $from_epar (@from_epars) {
            next if ($processed{$from_epar->id});
            $processed{$from_epar->id}++;
            my @functor_kids = grep {$_->functor eq $to_node->functor} $from_epar->get_echildren({or_topological => 1});
            if ($self->monolingual) {
                # following ensures that the ref node is generated with one of the 3 t_lemmas as well as not yet covered
                ($from_node) = grep { $_->t_lemma =~ /^(\#PersPron)|(\#Cor)|(\#Gen)$/ && $from_free->{$_->id} } @functor_kids;
            }
            else {
                ($from_node) = @functor_kids;
            }
            last if ($from_node);
        }
        
        if ($from_node) {
            $from_node->add_aligned_node( $to_node, $self->_align_name );
            delete $to_free->{$to_node->id};
            delete $from_free->{$from_node->id};
        }
    }
}

sub align_generated_nodes_by_functor_parent {
    my ($self, $to_free ) = @_;

    foreach my $to_node (values %$to_free) {
        my $to_par = $to_node->get_parent;
        next if (!$to_par);
        my ($from_par) = Treex::Tool::Align::Utils::aligned_transitively([$to_par], [ $self->_align_filter('backwards') ]);
        next if (!$from_par);
        my ($from_eq) = grep {$_->functor eq $to_node->functor} $from_par->get_echildren({or_topological => 1});
        next if (!$from_eq);
        my ($to_eq) = Treex::Tool::Align::Utils::aligned_transitively([$from_eq], [ $self->_align_filter('forwards') ]);
        next if (!$to_eq);
        next if ($to_eq->clause_number == $to_node->clause_number);
        
        $from_eq->add_aligned_node( $to_node, $self->_align_name('loose') );
        delete $to_free->{$to_node->id};
    }
}

sub align_arguments_of_nonfinites_to_grandparents {
    my ($self, $to_free) = @_;

    foreach my $to_node (values %$to_free) {
        my $to_par = $to_node->get_parent;
        next if (!$to_par);
        my ($from_par) = Treex::Tool::Align::Utils::aligned_transitively([$to_par], [ $self->_align_filter('backwards') ]);
        next if (!$from_par);
        next if (!defined $from_par->formeme || $from_par->formeme !~ /^adj/);
        
        my @from_grand_epars = $from_par->get_eparents({or_topological => 1});
        foreach my $from_grand_epar (@from_grand_epars) {
            $from_grand_epar->add_aligned_node( $to_node, $self->_align_name('loose') );
        }
        delete $to_free->{$to_node->id};
    }

}

sub align_generated_nodes_to_coref_ante_counterpart {
    my ($self, $from_free, $direction) = @_;
    foreach my $from_node (values %$from_free) {
        my @antes = grep {$_->get_root == $from_node->get_root} $from_node->get_coref_chain;
        next if (!@antes);
        my ($to_ante) = Treex::Tool::Align::Utils::aligned_transitively(\@antes, [ $self->_align_filter($direction) ]);
        next if (!defined $to_ante);
        if ($direction eq 'forwards') {
            $from_node->add_aligned_node($to_ante, $self->_align_name('loose'));
        } 
        else {
            $to_ante->add_aligned_node($from_node, $self->_align_name('loose'));
        }
        delete $from_free->{$from_node->id};
    }
}

1;

=head1 NAME

Treex::Block::Align::T::AlignGeneratedNodes

=head1 DESCRIPTION

A block for alignment of generated nodes.
Originally this was designed for monolingual alignment, i.e. aligning between gold and automatically analysed trees.
Recently, this block was generalized to guess even cross-lingual alignment links between generated nodes.
Use C<monolingual=0> if alignment between different languages is sought.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
