package Treex::Block::T2T::EN2CS::TrFTryRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::EN;
use Treex::Tool::Lexicon::CS;

#TODO These hacks should be removed from here and added to formeme translation models
# Explanation:
# Hand-written tables like this one are evil - this is not the way how final TectoMT should work.
# The only purpose of this table is to help develop and debug better machine-learnt translation
# of formemes. When new block for formeme translation will be ready, it must have better results
# when applied without these quick-fixs.
Readonly my %QUICKFIX_TRANSLATION_OF => (
    ## These formemes are not covered by the current formeme dictionary
    'x'                 => 'x',
    'n:adv'             => 'n:4',
    'n:unlike+X'        => 'n:na_rozdíl_od+2',
    'n:of_up_to+X'      => 'n:dosahující_až+2',
    'n:in_case_of+X'    => 'n:v_případě+2',
    'n:more_than+X'     => 'n:více_než+1',
    'n:less_than+X'     => 'n:méně_než+1',
    'n:a+X'             => 'n:za+4',
    'n:as_regards+X'    => 'n:pokud_jde_o+4',
    'n:as_for+X'        => 'n:pokud_jde_o+4',
    'v:as_long_as+fin'  => 'v:dokud+fin',
    'v:even_though+fin' => 'v:přestože+fin',
    'v:even_if+fin'     => 'v:i_když+fin',
    'v:as_though+fin'   => 'v:jakoby+fin',
    'n:worth+X'         => 'n:za+4',
    'n:according_to+X'  => 'n:podle+2',
    'v:given_that+fin'  => 'v:jelikož+fin',

    ## These formemes are sometimes translated strangely by the current dict.
    #    'n:subj'        => 'n:1',
    'v:because+fin' => 'v:protože+fin',
    'v:rc'          => 'v:rc',
    'v:while+fin'   => 'v:zatímco+fin',
    'v:as+fin'      => 'v:jak+fin',
    'n:up_to+X'     => 'n:až+4',
    'adj:up_to+X'   => 'adj:až_do+4',

    #    'n:poss'        => 'n:2',
    'n:of_over+X' => 'n:převyšující+2',
    'n:of_ago+X'  => 'n:před+7',
    'v:inf'       => 'v:inf',
);

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $cs_tnode->formeme_origin ne 'clone';

    my $en_tnode = $cs_tnode->src_tnode;
    return if !$en_tnode;

    my $cs_formeme = formeme_for_tnode( $en_tnode, $cs_tnode );
    if ( defined $cs_formeme ) {
        $cs_tnode->set_formeme($cs_formeme);
        $cs_tnode->set_formeme_origin('rule-Translate_F_try_rules');
    }
    return;
}

sub formeme_for_tnode {
    my ( $en_tnode,  $cs_tnode )   = @_;
    my ( $en_tlemma, $en_formeme ) = $en_tnode->get_attrs(qw(t_lemma formeme));
    my $en_parent = $en_tnode->get_parent();

    return 'n:v+4' if $en_tlemma =~ /^(sun|mon|tues|wednes|thurs|fri|satur)day$/i && $en_formeme eq 'n:on+X';
    return 'n:v+6' if $en_tlemma eq 'abroad' && $en_formeme eq 'adv:';
    return 'adj:poss' if $en_tlemma eq '#PersPron' && $en_formeme eq 'n:poss';
    return 'n:2' if $en_formeme eq 'n:poss' && ($en_tnode->get_children || ( $en_tnode->gram_number || '' ) eq 'pl');

    #    return 'n:attr' if $en_tnode->get_parent->is_name_of_person && Treex::Tool::Lexicon::EN::PersonalRoles::is_personal_role($en_tlemma) && $en_formeme eq 'n:attr';

    if ( my $n_node = $en_tnode->get_n_node ) {
        return 'adj:attr' if $en_formeme eq 'n:poss' and $n_node->get_attr('ne_type') =~ /^g/;
    }

    return 'n:attr' if $en_parent->is_name_of_person && $en_formeme eq 'n:attr';

    return 'n:attr' if ( $en_tnode->is_name_of_person || $en_tlemma =~ /^[\p{isUpper}\d]+$/ ) && $en_formeme eq 'n:attr';
    return 'n:attr' if $en_tlemma =~ /^(which|whose|that|this|these)$/ && $en_formeme eq 'n:attr';
    return 'adv:' if $en_tlemma eq 'addition' && $en_formeme eq 'n:in+X';

    return 'n:1' if $en_formeme eq 'n:subj' and $en_tlemma !~ /^(today|yesterday|now|first|second|then|however|moreover|nowadays)$/;    # potential wrongly marked subjects

    #if ( $en_formeme eq 'v:fin' ) {
    #    my $en_parent = $en_tnode->get_parent();
    #    return 'v:fin' if $en_parent->is_root();
    #    my $p_lemma = $en_parent->t_lemma;
    #    return 'v:že+fin' if Treex::Tool::Lexicon::EN::is_dicendi_verb($p_lemma);
    #    return 'v:fin';
    #}

    if ( $en_formeme eq 'v:so_that+fin' ) {
        my $cs_parent = $cs_tnode->get_parent();
        my $tak       = $cs_parent->create_child(
            {   t_lemma        => 'tak',
                formeme        => 'adv:',
                mlayer_pos     => 'D',
                t_lemma_origin => 'rule-Translate_F_try_rules',
                formeme_origin => 'rule-Translate_F_try_rules',
                'gram/sempos'  => 'adv.pron.def',
                'nodetype'     => 'complex',
                'functor'      => '???',
            }
        );
        $tak->shift_before_subtree($cs_tnode);
        return 'v:aby+fin';
    }

    return 'v:zda+fin' if ( ($en_parent->t_lemma // '') eq 'check' and $en_formeme eq 'v:if+fin' );

    return $QUICKFIX_TRANSLATION_OF{$en_formeme};
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::TrFTryRules

Try to apply some hand written rules for formeme translation.
If succeeded, formeme is filled and atributte C<formeme_origin> is set to I<rule>.

Actually there are only few quickfix hacks in this block.

=back

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
