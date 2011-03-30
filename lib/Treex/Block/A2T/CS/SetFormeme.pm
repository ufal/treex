package Treex::Block::A2T::CS::SetFormeme;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # First, fill formeme of all t-layer nodes with a default value,
    # so tedious undef checking (||'') is no more needed.
    $t_node->set_formeme('???');

    # For complex type nodes (i.e. almost all except coordinations, rhematizers etc.)
    # fill in formemes
    if ( $t_node->nodetype eq 'complex' ) {
        detect_formeme($t_node);
    }
    return;
}

sub detect_formeme {
    my ($tnode) = @_;
    my $lex_a_node    = $tnode->get_lex_anode() or return;
    my @aux_a_nodes   = $tnode->get_aux_anodes();
    my $tag           = $lex_a_node->tag;
    my ($tparent)     = $tnode->get_eparents({or_topological => 1});
    my $sempos        = $tnode->get_attr('gram/sempos') || '';
    my $parent_sempos = $tparent->get_attr('gram/sempos') || '';
    my $parent_anode  = $tparent->get_lex_anode();
    my $parent_tag    = ($parent_anode) ? $parent_anode->tag : '';
    my $formeme;

    # semantic nouns
    if ( $sempos =~ /^n/ ) {
        if ( $tag =~ /^(AU|PS|P8)/ ) {
            $formeme = 'n:poss';
        }
        elsif ( $tag =~ /^[NAP]...(\d)/ ) {
            my $case = $1;
            my $prep = join '_',
                map { my $preplemma = $_->lemma; $preplemma =~ s/\-.+//; $preplemma }
                grep { $_->tag =~ /^R/ or $_->afun =~ /^Aux[PC]/ or $_->lemma eq 'jako' } @aux_a_nodes;
            if ( $prep ne '' ) {
                $formeme = "n:$prep+$case";
            }
            elsif ( $parent_sempos =~ /^n/ and $tparent->ord > $tnode->ord ) {
                $formeme = 'n:attr';
            }
            else {
                $formeme = "n:$case";
            }
        }
        else {
            $formeme = 'n:???';
        }
    }

    # semantic adjectives
    elsif ( $sempos =~ /^adj/ ) {
        my $prep = join '_',
            map { my $preplemma = $_->lemma; $preplemma =~ s/\-.+//; $preplemma }
            grep { $_->tag =~ /^R/ or $_->afun =~ /^AuxP/ } @aux_a_nodes;
        if ( $prep ne '' ) {
            $formeme = "adj:$prep+X";
        }
        elsif ( $parent_sempos =~ /v/ ) {
            $formeme = 'adj:compl';
        }
        else {
            $formeme = 'adj:attr';
        }
    }

    # semantic adjectives
    elsif ( $sempos =~ /^adv/ ) {
        $formeme = 'adv:';
    }

    # semantic verbs
    elsif ( $sempos =~ /^v/ ) {
        if ( $tag =~ /^Vf/ and not grep { $_->tag =~ /^V[Bp]/ } @aux_a_nodes ) {
            $formeme = 'v:inf';
        }
        else {
            my $subconj = join '_',
                map { my $subconjlemma = $_->lemma; $subconjlemma =~ s/\-.+//; $subconjlemma }
                grep { $_->tag =~ /^J,/ or $_->form eq "li" } @aux_a_nodes;

            if ( $tnode->is_relclause_head ) {
                $formeme = 'v:rc';
            }
            elsif ( $subconj ne '' ) {
                $formeme = "v:$subconj+fin";
            }
            else {
                $formeme = 'v:fin';
            }
        }
    }

    if ($formeme) {
        $tnode->set_formeme($formeme);
    }
    return;
}

1;

=over

=item Treex::Block::A2T::CS::SetFormeme

The attribute C<formeme> of Czech t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:pro+X> (prepositional group), or C<n:1> are used.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
