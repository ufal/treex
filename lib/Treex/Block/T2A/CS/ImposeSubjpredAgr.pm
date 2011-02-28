package Treex::Block::T2A::CS::ImposeSubjpredAgr;
use utf8;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    foreach my $t_node ( $t_root->get_descendants() ) {
        if ( $t_node->formeme =~ /^v.+(fin|rc)/ ) {
            process_finite_verb($t_node);
        }
    }
    return;
}

sub process_finite_verb {
    my ($t_vfin) = @_;
    my $a_vfin   = $t_vfin->get_lex_anode();
    my $a_subj   = find_a_subject_of($a_vfin);

    if ( not $a_subj ) {

        # 'He managed to...' --> 'Podarilo se mu...'
        if ( $t_vfin->t_lemma =~ /^((po)?(dařit)|líbit)/ ) {
            $a_vfin->set_attr( 'morphcat/gender', 'N' );
            $a_vfin->set_attr( 'morphcat/number', 'S' );
            $a_vfin->set_attr( 'morphcat/person', '3' );
        }
        return;
    }

    my $subj_lemma = $a_subj->lemma;

    # 1. numeral subjects
    # 10 deti prislo ...., 1,1 litru benzinu bylo
    if ( is_neutrum_lemma($subj_lemma) ) {
        $a_vfin->set_attr( 'morphcat/gender', 'N' );
        $a_vfin->set_attr( 'morphcat/number', 'S' );
        $a_vfin->set_attr( 'morphcat/person', '3' );
        ## print STDERR "NEUTRUM !!!!!!!!\n";
        return;
    }

    if ( $subj_lemma =~ /^(nikdo|kdo|někdo|kdokoli)$/ ) {
        $a_vfin->set_attr( 'morphcat/gender', 'M' );

        # sg is default, but pl might have come from rel.clause agreement, 'those who came'
        if ( $a_subj->get_attr('morphcat/number') eq 'P' ) {
            $a_vfin->set_attr( 'morphcat/number', 'P' );
        }
        else {
            $a_vfin->set_attr( 'morphcat/number', 'S' );
        }

        $a_vfin->set_attr( 'morphcat/person', '3' );
        return;
    }

    # 2. other (normal) subjects
    foreach my $category ( 'gender', 'number', 'person' ) {
        $a_vfin->set_attr( "morphcat/$category", $a_subj->get_attr("morphcat/$category") );
        ## print STDERR "Copying $category ".$a_subj->get_attr("morphcat/$category")."\n";;
    }
    if ( $a_vfin->get_attr('morphcat/person') !~ /\d/ ) {
        $a_vfin->set_attr( 'morphcat/person', 3 );
    }

    # koordinovany subjekt -> sloveso v pluralu
    # "Plurál nebo singulár je/jsou ošidná mluvnická kategorie."
    if ( $a_subj->is_member && $a_subj->get_parent()->lemma ne 'nebo' ) {
        $a_vfin->set_attr( 'morphcat/number', 'P' );
    }

    return;
}

sub find_a_subject_of {
    my ($a_vfin) = @_;
    my @children = $a_vfin->get_echildren;
    my @subjects = grep { ( $_->afun || '' ) eq 'Sb' } @children;
    if (@subjects) {
        return $subjects[0];
    }
    return;
}

use CzechMorpho;
my $generator = CzechMorpho::Generator->new();

sub is_neutrum_lemma {
    my ($subj_lemma) = @_;
    return (
        ( $subj_lemma =~ /^\d+$/ && $subj_lemma > 4 )
            || $subj_lemma =~ /^\d+,\d+$/
            || $subj_lemma =~ /^(nic|mnoho|něco|několik|co|cokoliv)/

            # 'osm z deseti stacilo','malo stacilo'
            || first { $_->{tag} =~ /^C[na]/ }
        $generator->generate_all($subj_lemma)
    );
}

1;

=over

=item Treex::Block::T2A::CS::ImposeSubjpredAgr

Copy the values of morphological categories gender, number and person
according to the subject-predicate agreement, i.e.,
from the TCzechA node corresponding to the subject into the TCzechA
node corresponding to the (still unexpanded) verb node.
Special treatment of agreement in copula constructions.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
