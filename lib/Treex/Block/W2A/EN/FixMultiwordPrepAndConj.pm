package Treex::Block::W2A::EN::FixMultiwordPrepAndConj;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# viceslovne spojky nejcetnejsi v BNC (rucne profiltrovano, neco pridano):
my $MULTI_CONJ = qr/^(as well as|so that|as if|even if|even though|as though|rather than|as soon as|as long as|even when|in case of|in case|except that|given that|provided that|such that|as far as|in order to)$/;

# viceslovne predlozky nejcetnejsi v BNC (rucne profiltrovano):
my $MULTI_PREP = qr/^(more than|less than|out of|such as|because of|rather than|according to|away from|up to|on to|due to|as to|instead of|apart from|in front of|subject to|along with|prior to|next to|in spite of|ahead of|in accordance with|in response to|except for|with regard to|by means of|as regards|as for)$/;

sub process_atree {
    my ( $self, $a_root ) = @_;
    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    my %unproc_as_idxs_hash = ();

    my $starts_at;
    for ( $starts_at = 0; $starts_at <= $#anodes - 3; $starts_at++ ) {

        LENGTH_LOOP:
        foreach my $length ( 3, 2 ) {    # two- and three-word only so far
            my $string = join ' ', map { lc( $anodes[$_]->form ) } ( $starts_at .. $starts_at + $length - 1 );

            # Sometimes the matching string isn't a multiword preposition,
            # but RP (phrase verb particle) + common onword preposition:
            # "heat up to toxic levels" "He moved on to do his own work."
            last LENGTH_LOOP if $anodes[$starts_at]->tag eq 'RP';
            # "rather than" is coordinating, not subordinating conjunction in CoNLL 2007 English data.
            # This block is designed for subordinating conjunctions and must not damage coordination.
            # (Even if we allowed changing the structure, we would have to be much more careful with existing is_member values!)
            last LENGTH_LOOP if grep { $anodes[$_]->is_coap_root } ( $starts_at .. $starts_at + $length - 1 );
            my ($conj) = $string =~ $MULTI_CONJ;
            my ($prep) = $string =~ $MULTI_PREP;
            if (!$conj && !$prep) {
                if ($anodes[$starts_at]->form eq 'as') {
                    $unproc_as_idxs_hash{$starts_at}++;
                }
                next LENGTH_LOOP;
            }
            $conj ||= '';
            my $first = $anodes[$starts_at];
            my @others = map { $anodes[$_] } ( $starts_at + 1 .. $starts_at + $length - 1 );

            #  nejdriv se prvni clen prevesi tam, kde byl z nich nejvyssi
            my ($highest) = sort { $a->get_depth <=> $b->get_depth } ( $first, @others );
            if ( $highest != $first ) {
                $first->set_parent( $highest->get_parent );
                $first->set_is_member( $highest->is_member );
                $highest->set_is_member(0);
            }

            # a pak se ostatni casti viceslovne spojky prevesi pod prvni
            foreach my $other (@others) {
                $other->set_afun( $conj ? 'AuxC' : 'AuxP' );
                $other->set_parent($first);
                $other->set_is_member(0);
            }

            # a jejich deti se prevesi taky rovnou pod prvni
            foreach my $other (@others) {
                foreach my $child ( $other->get_children() ) {
                    $child->set_parent($first);
                }
            }

            # prevesit predlozky zavisle na predlozce, ktere ale nejsou soucasti viceslovne; mozna by to chtelo povysit
            my @to_rehang = grep {
                $_->tag eq 'IN' && ( $_->afun || '' ) !~ 'Aux[CP]'
            } $highest->get_children();
            foreach my $rehang (@to_rehang) {
                $rehang->set_parent( ( $highest->get_eparents() )[0] );
            }

            # Fill afun
            my $afun = $conj ? 'AuxC' : 'AuxP';
            if ( $conj eq 'as well as' ) {

                # TODO: better recognition of memebers of this coord
                my @members = grep { $_->tag !~ /^(,|RB|IN)/ } $first->get_children();
                if (@members) {
                    $afun = 'Coord';
                    foreach my $member (@members) {
                        $member->set_is_member(1);
                    }
                }
            }
            $first->set_afun($afun);

            # aby se ty viceslovne predlozky nahodou neprekryly
            $starts_at += $length;
            last LENGTH_LOOP;
        }
    }

    my @unproc_as_idxs = sort {$a <=> $b} keys %unproc_as_idxs_hash;
    $self->as_X_as_Y(\@anodes, \@unproc_as_idxs);

    return 1;
}

sub as_X_as_Y {
    my ($self, $a_nodes, $unproc_as_idxs) = @_;

    return if (@$unproc_as_idxs < 2);

    my $as1_idx = shift @$unproc_as_idxs;
    while (my $as2_idx = shift @$unproc_as_idxs) {
        my @a_nodes_inbetw = @$a_nodes[ $as1_idx+1 .. $as2_idx-1 ];

        # also such obvious mistakes as 'as as' appear
        if (@a_nodes_inbetw == 0) {
            $as1_idx = $as2_idx;
            next;
        }

        # no already processed 'as' in between
        if (grep {$_->form eq 'as'} @a_nodes_inbetw) {
            $as1_idx = $as2_idx;
            next;
        }

        # no verb can be in between
        if (grep {$_->tag =~ /^V/} @a_nodes_inbetw) {
            $as1_idx = $as2_idx;
            next;
        }

        # the first as must be succeeded by an adjective or adverb
        if ($a_nodes_inbetw[0]->tag !~ /^(RB)|(JJ)$/) {
            $as1_idx = $as2_idx;
            next;
        }

        # select the head of the X part
        my ($X_head) = sort {$a->get_depth <=> $b->get_depth} @a_nodes_inbetw;
        my %phrase_ids_map = map {$_->id => 1} $X_head->get_descendants({add_self => 1});

        # all nodes in between must belong to the same phrase
        my @in_phrase = grep {$phrase_ids_map{$_->id}} @a_nodes_inbetw;
        if (@in_phrase != @a_nodes_inbetw) {
            $as1_idx = $as2_idx;
            next;
        }

        # select all necessary members
        # as' involved
        my $as1 = $a_nodes->[$as1_idx];
        my $as2 = $a_nodes->[$as2_idx];
        # first word of Y
        my $Y_first = $a_nodes->[$as2_idx+1];
        # super parent that governs as', X and Y
        my $super_parent = $Y_first;
        while (!all {$_->is_descendant_of($super_parent)} ($as1, $as2, $X_head, $Y_first)) {
            $super_parent = $super_parent->get_parent;
        }
        my %indicator = map {$_->id => 1} ($as1, $as2, $super_parent, $X_head);
        # the head of Y is guessed
        my $Y_head = $Y_first;
        while (!$indicator{$Y_head->get_parent->id}) {
            $Y_head = $Y_head->get_parent;
            if (!defined $Y_head->get_parent) {
                print STDERR "ID: $Y_head->id\n";
            }
        }
        #my ($sp_equal) = grep {$_ == $super_parent} ($as1, $as2, $X_head, $Y_head);
        #if (defined $sp_equal) {
        #    $super_parent = $sp_equal->parent;
        #}

        # rehang all involved members to their common ancestor
        # just to prevent from making a cycle
        $as1->set_parent($super_parent);
        $as2->set_parent($super_parent);
        $X_head->set_parent($super_parent);
        $Y_head->set_parent($super_parent);


        # final rehanging
        $X_head->set_parent($as1);
        $as2->set_parent($as1);
        $Y_head->set_parent($as2);

        # update coordination membership after rehanging
        foreach my $node ($as1, $as2, $super_parent, $X_head, $Y_head) {
            $node->set_is_member(0);
        }
        if (any {$_->is_member} $as1->get_siblings) {
            $as1->set_is_member(1);
        }

        # TODO temporary solution: the configuration that achieves
        # the best translation score
        # in fact, both should be aux and obtain a special formeme
        # on the t-layer
        $as1->set_afun('Adv');
        $as2->set_afun('AuxC');

        # we've found as+X+as+Y, so we have to skip processing of the span after the second "as"
        $as1_idx = shift @$unproc_as_idxs;
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::FixMultiwordPrepAndConj

=head1 DESCRIPTION

Normalizes the way how multiword prepositions (such as
'because of') and subordinating conjunctions (such as
'provided that', 'as soon as') are treated: first token
becomes the head and the other ones become its immediate
children, all marked with AuxC afun. Illusory overlapping
of multiword conjunctions (such as in 'as well as if') is
prevented.

In addition to 'as well/long/soon/far as', other spans
that match the pattern 'as X as Y' are being resolved here.
The involved nodes are reorganized as follows: as1<X as2<Y>>.
Afuns for both 'as' are set.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
