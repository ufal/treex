package SEnglishT_to_TCzechT::Translate_L_try_rules;

use 5.008;
use strict;
use warnings;
use utf8;
use Readonly;
use List::MoreUtils qw( any all );

use base qw(TectoMT::Block);

#TODO These hacks should be removed from here and added to the translation dictionary
Readonly my %QUICKFIX_TRANSLATION_OF => (
    q{as_well_as}  => 'i|J',
    q{as_well}     => 'také|D',
    q{``}          => '„|Z',
    q{''}          => '“|Z',
    q{a. m.}       => 'hodin ráno|X',
    q{p. m.}       => 'hodin odpoledne|X',
    q{e. g.}       => 'například|D',
    q{U. S.}       => 'USA|N',
    q{Mrs.}        => 'paní|N',
    q{Mr.}         => 'pan|N',
    q{Ms.}         => 'slečna|N',
    q{Obama}       => 'Obama|N',
 );

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {

        # Skip nodes that were already translated by other rules
        next if $cs_tnode->get_attr('t_lemma_origin') !~ /^clone/;

        my $en_tnode = $cs_tnode->get_source_tnode() or next;
        my $lemma_and_pos = get_lemma_and_pos( $en_tnode, $cs_tnode );
        if ( defined $lemma_and_pos ) {
            my ( $cs_tlemma, $m_pos ) = split /\|/, $lemma_and_pos;
            $cs_tnode->set_attr( 't_lemma',        $cs_tlemma );
            $cs_tnode->set_attr( 't_lemma_origin', 'rule-Translate_L_try_rules' );
            $cs_tnode->set_attr( 'mlayer_pos',     $m_pos )
        }
    }
    return;
}

sub get_lemma_and_pos {
    my ( $en_tnode,  $cs_tnode )   = @_;
    my ( $en_tlemma, $en_formeme ) = $en_tnode->get_attrs(qw(t_lemma formeme));

    # PersProns like "that" should be translated as "ten"
    if ($en_tlemma eq '#PersPron'
        && $en_formeme !~ /poss/    #"its" is excluded
        && $cs_tnode->get_attr('gram/number') eq 'sg'
        && $cs_tnode->get_attr('gram/gender') eq 'neut'
        && $en_tnode->get_lex_anode()->get_attr('m/lemma') ne 'itself'
        )
    {
        $cs_tnode->set_attr( 'gram/person', undef );
        $cs_tnode->set_attr( 'gram/sempos', 'n.pron.indef' );
        return 'ten|P';
    }

    # Don't translate other t-lemma substitutes (like #PersPron, #Cor, #QCor, #Rcp)
    return $en_tlemma if $en_tlemma =~ /^#/;

    # Prevent some errors/misses in dictionaries
    my $lemma_and_pos = $QUICKFIX_TRANSLATION_OF{$en_tlemma};
    return $lemma_and_pos if $lemma_and_pos;

    # either ... or -> buď' ... nebo
    # but skip nodetype=complex ("in the EU or the USA either" -> "v EU ani v USA")

    if ($en_tlemma =~ /^(n?either_n?or)$/) {
        if ($en_tlemma =~ /n/) {
            return 'ani';
        }
        else {
            return 'nebo';
        }
    }


    return 'buď' if $en_tlemma eq 'either' && $en_tnode->get_attr('nodetype') eq 'coap';

    if ( $en_tlemma eq 'late' && $en_tnode->get_attr('gram/degcmp') eq 'sup' ) {
        $cs_tnode->set_attr( 'gram/degcmp', 'pos' );
        return 'poslední|A';
    }

    # "As follows from ..." -> "Jak vyplývá z ..."
    if ( $en_tlemma eq 'follow' ) {
        return 'vyplývat|V' if any { $_->get_attr('formeme') =~ /from/ } $en_tnode->get_children( { following_only => 1 } );
    }

    # If no rules match, get_lemma_and_pos has not succeeded.
    return undef;
}

1;

__END__

=over

=item SEnglishT_to_TCzechT::Translate_L_try_rules

Try to apply some hand written rules for t-lemma translation.
If succeeded, t-lemma is filled and atributte C<t_lemma_origin> is set to I<rule>.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

