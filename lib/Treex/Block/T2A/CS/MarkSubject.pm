package Treex::Block::T2A::CS::MarkSubject;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @tnodes = $t_root->get_descendants();

    my %to_avoid;

    # avoiding nominatives in prepositional groups (such as 'n:jako+1')
    # avoiding temporal modifiers (today, this time.TWHEN)
    foreach my $tnode (@tnodes) {
        if (( $tnode->formeme =~ /\+1/ or $tnode->functor =~ /^T/ )
            and my $anode = $tnode->get_lex_anode()
            )
        {
            $to_avoid{$anode} = 1;
        }
    }

    foreach my $t_vfin ( grep { $_->formeme =~ /^v.+(fin|rc)/ } @tnodes ) {

        my $a_vfin = $t_vfin->get_lex_anode;
        if ( my $a_subj = _find_subject( $a_vfin, \%to_avoid ) ) {
            $a_subj->set_afun('Sb');

            #	    print $a_subj->id."\t".$a_subj->lemma."\n";
        }
    }
}

sub _find_subject {
    my ( $a_vfin, $to_avoid_ref ) = @_;

    my @candidates = (
        ( reverse $a_vfin->get_echildren( { preceding_only => 1 } ) ),
        $a_vfin->get_echildren( { following_only => 1 } )
    );

    my @nominatives = grep {
        ( $_->get_attr('morphcat/case') || "" ) eq '1'
            and not $to_avoid_ref->{$_}
    } @candidates;

    return if !@nominatives;

    # Copula verbs with "be" are tricky.
    # "That was the mechanism." -> "Toto byl ten mechanismus" (not "Toto bylo...")
    # In English "that" is a subject and "mechanism" an object.
    # However in Czech, "mechanismus" is the subject because of the verb agreement.
    # Let's try heuristics: Czech subject is the first nominative
    # other than lemma "tento".
    if ( $a_vfin->lemma eq 'být' ) {
        my ($copula_subj) = grep { $_->lemma !~ /^(tento|ten)$/ } @nominatives;
        return $copula_subj if $copula_subj;
    }
    return $nominatives[0];
}

1;

=over

=item Treex::Block::T2A::CS::MarkSubject

Subjects of finite clauses are distinguished by
filling the afun attribute. Prepositional nominatives are avoided.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
