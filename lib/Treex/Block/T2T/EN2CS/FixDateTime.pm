package Treex::Block::T2T::EN2CS::FixDateTime;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use Lexicon::Czech;

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $lemma = $t_node->t_lemma || ''; #TODO why || ''?
    if    ( $lemma =~ /^[12]\d\d\ds?$/ )          { process_year($t_node); }
    elsif ( $lemma =~ /^[12]\d\d\d-[12]\d\d\d$/ ) { process_range_of_years($t_node); }
    elsif ( $lemma =~ /^\d\d?\.?$/ )              { process_month($t_node); }
    return;
}

sub process_year {
    my ($t_node) = @_;
    my $en_t_node = $t_node->src_tnode or return;
    my $year      = $t_node->t_lemma;
    my $new_node  = $t_node->get_parent()->create_child(
        {   attributes => {
                't_lemma'        => 'rok',
                'nodetype'       => 'complex',
                'functor'        => '???',
                'gram/sempos'    => 'n.denot',
                'formeme'        => $t_node->formeme,
                'gram/number'    => 'sg',
                'gram/gender'    => 'inan',
                'mlayer_pos'     => 'N',
                'formeme_origin' => 'rule-Fix_date_time(' . $t_node->formeme_origin . ')',
                }
        }
    );

    # The new node's source/head.rf should point to the English year-node.
    # (It is useful e.g. when checking source node's formeme.)

    $new_node->set_src_tnode($en_t_node);

    # "in 1980's" -> "v 80. letech"
    # "in 1980s"  -> "v 80. letech"
    if ($year =~ /0s$/
        ||
        ( $year =~ /0$/ && any { $_->form eq "\'s" } $en_t_node->get_aux_anodes() )
        )
    {
        $year =~ /(..)s?$/;
        $t_node->set_t_lemma("$1.");
        $t_node->set_t_lemma_origin('rule-Fix_date_time');
        $new_node->shift_after_node( $t_node, { without_children => 1 } );
        $new_node->set_attr( 'gram/number', 'pl' );
        $new_node->set_attr( 'gram/gender', 'neut' );    # to distinguish "v rocích" and "v letech"
    }

    # "in 1980" -> "v roce 1980"
    else {
        $new_node->shift_before_node( $t_node, { without_children => 1 } );
        $new_node->set_attr( 'gram/number', 'sg' );
    }

    $t_node->set_formeme('x');
    $t_node->set_formeme_origin('rule-Fix_date_time');
    $t_node->set_parent($new_node);
    foreach my $child ( $t_node->get_children() ) {
        $child->set_parent($new_node);
    }
    return;
}

sub process_range_of_years {
    my ($t_node) = @_;
    my $en_t_node = $t_node->src_tnode;
    my ( $first, $second ) = split( /-/, $t_node->t_lemma );

    # new node 'rok'
    my $rok_node = $t_node->get_parent()->create_child(
        {   attributes => {
                't_lemma'        => 'rok',
                'nodetype'       => 'complex',
                'functor'        => '???',
                'gram/sempos'    => 'n.denot',
                'gram/number'    => 'pl',
                'gram/gender'    => 'neut',                                                  # 'v letech...', not 'v rocich...'
                'mlayer_pos'     => 'N',
                'formeme'        => $t_node->formeme,
                'formeme_origin' => 'rule-Fix_date_time(' . $t_node->formeme_origin . ')',
                }
        }
    );
    $rok_node->shift_before_node( $t_node, { without_children => 1 } );
    $rok_node->set_src_tnode($en_t_node);

    # first year node
    $t_node->set_t_lemma($first);
    $t_node->set_formeme('x');
    $t_node->set_formeme_origin('rule-Fix_date_time');
    $t_node->set_parent($rok_node);
    foreach my $child ( $t_node->get_children() ) {
        $child->set_parent($rok_node);
    }

    # second year node
    my $second_node = $t_node->get_parent()->create_child(
        {   attributes => {
                't_lemma'        => $second,
                'nodetype'       => 'complex',
                'functor'        => '???',
                'gram/sempos'    => 'n.denot',
                'formeme'        => 'n:až+X',
                'formeme_origin' => 'rule-Fix_date_time',
                }
        }
    );
    $second_node->shift_after_node( $t_node, { without_children => 1 } );
    $second_node->set_src_tnode($en_t_node);

    return;

}

sub process_month {
    my ($t_node) = @_;
    my $parent = $t_node->get_parent();
    return if $parent->is_root();
    return if !Lexicon::Czech::number_of_month( $parent->t_lemma );
    return if $t_node->precedes($parent);

    # 4th -> 4. -> 4. (unchanged)
    # 4   -> 4  -> 4. (period added)
    my $t_lemma = $t_node->t_lemma;
    if ( $t_lemma !~ /\.$/ ) {
        $t_node->set_t_lemma( $t_lemma . '.' );
        $t_node->set_t_lemma_origin('rule-Fix_date_time');
    }

    # Change word order
    $t_node->shift_before_node( $parent, { without_children => 1 } );
    my $p_formeme = $parent->formeme;

    # "on January 9" -> "9. ledna"
    if ( $p_formeme =~ /^n:(na|v)/ ) {
        $parent->set_formeme('n:2');
        $parent->set_formeme_origin('rule-Fix_date_time');
    }
    return;
}

1;

=over

=encoding utf8

=item Treex::Block::T2T::EN2CS::FixDateTime

Rule-based correction of translations of date/time expressions
(1970's --> 70. léta, July 1 --> 1. červenec, etc.)

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
