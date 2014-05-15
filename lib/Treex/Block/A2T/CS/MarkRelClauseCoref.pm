package Treex::Block::A2T::CS::MarkRelClauseCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    my $lex_anode_tag = $self->_get_lex_anode_tag($t_node);
    my $antec;

    # relative pronouns without "coz"
    if ( $lex_anode_tag =~ /^.[149JK\?]/ ) {

        my $relclause = $t_node->get_clause_head;        
        if (!$relclause->is_root){ # probably due to parsing errors, this happens from time to time
            my @e_parents = $relclause->get_eparents( { or_topological => 1 } );
            if ( scalar @e_parents > 1 ) {
    
                my @depth_sorted = sort { $a->get_depth <=> $b->get_depth } @e_parents;
                $antec = shift @depth_sorted;
                while ( ( grep { !$_->is_descendant_of($antec) } @depth_sorted ) > 0 ) {
                    $antec = $antec->get_parent;
                }
    
            }
            else {
                $antec = $e_parents[0];
            }
            # cancel the link if it points to a verb
            #if (defined $antec && $antec->gram_sempos eq "v") {
            #    $antec = undef;
            #}
        }
    }

    # relative pronoun "coz"
    elsif ( $lex_anode_tag =~ /^.E/ ) {

        my $parent = $t_node->get_parent;
        if (   defined $parent
            && defined $parent->get_parent &&
            defined $parent->get_parent->get_lex_anode &&
            $parent->get_parent->get_lex_anode->lemma =~ /^[,-]$/ &&
            defined $parent->get_left_neighbor
            )
        {
            $antec = $parent->get_left_neighbor;
        }
        else {
            my @nodes = grep {$_->ord < $t_node->ord} 
                $t_node->get_root->get_descendants({ordered => 1});
            my @clause_heads = grep {$_->is_clause_head} @nodes;

            if (@clause_heads > 0) {
                $antec = pop @clause_heads;
            }



            #my $doc   = $t_node->get_document;
            #my @trees = map {
            #    $_->get_tree(
            #        $t_node->language, $t_node->get_layer, $t_node->selector
            #        )
            #} $doc->get_bundles;

            #my $tree_idx = List::MoreUtils::first_index { $_ == $t_node->get_root } @trees;

            #if ( $tree_idx > 0 ) {
            #    my $prev_tree = $trees[ $tree_idx - 1 ];

            #    my @prev_verbs = sort { $a->get_depth <=> $b->get_depth }
            #        (
            #        grep { defined $_->get_lex_anode && $_->get_lex_anode->tag =~ /^V/ }
            #            $prev_tree->descendants
            #        );

                #$antec = $prev_verbs[0];

                #my @prev_words = $prev_tree->descendants({ordered => 1});
                #$antec = first { defined $_->get_lex_anode
                #    && $_->get_lex_anode->tag =~ /^V/ } reverse @prev_words;
            #}

        }

    }

    if ( defined $antec && !$antec->is_root ) {    # klauze se nasla a tudiz to nedobehlo az ke koreni
        $t_node->set_deref_attr( 'coref_gram.rf', [$antec] );
    }
}

sub _get_lex_anode_tag {
    my ($self, $tnode) = @_;
    my $anode = $tnode->get_lex_anode();
    return '' if (!$anode);
    return $anode->tag // '';
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::MarkRelClauseCoref

=head1 DESCRIPTION

Coreference link between a relative pronoun (or other relative pronominal word)
and its antecedent (in the sense of grammatical coreference) is detected in Czech t-trees
and stored into the C<coref_gram.rf> attribute.

This implementation uses the rules given by Nguy (2006, pp. 44-7)
L<http://ufal.mff.cuni.cz/~linh/theses/aca-diplomka.pdf>, with simple heuristics
to compensate for parser errors.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
