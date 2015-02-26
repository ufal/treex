package Treex::Block::T2T::EN2PT::AddRelpronBelowRc;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    RELCLAUSE:  
    foreach my $rc_head ( grep { $_->formeme =~ /rc/ } $t_root->get_descendants ) {

        # TODO: add "qual" (but it is a grandson, not a son node)
        next RELCLAUSE if grep {$_->t_lemma =~ /^(que|onde|cujo)$/} $rc_head->get_children; # TODO: it is rather the formeme that should be fixed (not here, but upstream)

        my $src_tnode = $rc_head->src_tnode;
        next RELCLAUSE if !$src_tnode;
        next RELCLAUSE 
            if (($src_tnode->formeme =~ /rc/) && !$src_tnode->wild->{rc_no_relpron});

        # Grammatical antecedent is typically the nominal parent of the clause
        my ($gram_antec) = $rc_head->get_eparents( { ordered => 1 } );
        next RELCLAUSE if !$gram_antec;
        next RELCLAUSE if $gram_antec->formeme !~ /^n/;
        
        # Create new t-node
        my $relpron = $rc_head->create_child(
            {   nodetype         => 'complex',
                functor          => '???',
                formeme          => 'n:obj',
                t_lemma          => 'que',
                t_lemma_origin   => 'Add_relpron_below_rc',
                'gram/sempos'    => 'n.pron.indef',
                'gram/indeftype' => 'relat',

            }
        );

        $relpron->shift_before_subtree($rc_head);
    }
    return;
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::T2T::EN2PT::AddRelpronBelowRc

=head1 DESCRIPTION

Generating new t-nodes corresponding to relative pronoun 'ktery' below roots
of relative clauses, whose source-side counterparts were not relative
clauses (e.g. when translatin an English gerund to a Czech relative
clause ). Grammatical coreference is filled too.

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.