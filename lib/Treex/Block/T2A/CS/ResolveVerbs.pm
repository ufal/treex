package Treex::Block::T2A::CS::ResolveVerbs;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';



sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $formeme = $t_node->formeme;
    my $pos = $t_node->get_attr('mlayer_pos') || '';

    # Skip everything except verbs
    return if $formeme !~ /^v/ && $pos ne 'V';

    my $sentmod = $t_node->sentmod || '';
    my $a_node = $t_node->get_lex_anode();

    if ( $formeme =~ /inf/ ) { resolve_infinitive( $t_node, $a_node ); }
    elsif ( $sentmod eq 'imper' ) { resolve_imperative( $t_node, $a_node ); }
    else {
        ## Skip nodes with already filled values
        my ( $old_subpos, $old_tense ) = $a_node->get_attrs(qw(morphcat/subpos morphcat/tense));
        return if $old_subpos && $old_subpos ne '.' && $old_tense && $old_tense ne '.';

        # Fill subPOS and tense
        my ( $subpos, $tense ) = get_subpos_tense_of_finite( $t_node, $a_node );
        $a_node->set_attr( 'morphcat/subpos', $subpos );
        $a_node->set_attr( 'morphcat/tense', $tense ) if $tense;
    }
    return;
}

sub resolve_infinitive {
    my ( $t_node, $a_node ) = @_;
    $a_node->set_attr( 'morphcat/subpos', 'f' );
    $a_node->set_attr( 'morphcat/voice',  '-' );
    return;
}

sub resolve_imperative {
    my ( $t_node, $a_node ) = @_;

    $a_node->set_attr( 'morphcat/subpos', 'i' );
    $a_node->set_attr( 'morphcat/tense',  '-' );
    $a_node->set_attr( 'morphcat/voice',  '-' );
    $a_node->set_attr( 'morphcat/person', '2' );    #1 is also possible but rare and Generate_wordforms would prefere it

    #Without this hack Generate_wordforms would come up with 'budiž'
    if ( $a_node->lemma eq 'být' ) {
        $a_node->set_form('buďte');
        $a_node->set_attr( 'morphcat/pos', '!' );
    }
    return;
}

sub get_subpos_tense_of_finite {
    my ( $t_node, $a_node ) = @_;
    my $tense   = $t_node->get_attr('gram/tense')   || '';
    my $verbmod = $t_node->get_attr('gram/verbmod') || '';
    my $voice   = $t_node->voice        || '';
    my $aspect  = $t_node->get_attr('gram/aspect')  || '';
    my $formeme = $t_node->formeme;

    return ( 'p', undef ) if $tense eq 'ant' || $verbmod eq 'cdn' || $formeme =~ /aby|kdyby/;

    # futurum vyjadrene pomocnym byt, ktere je ted korenem
    # opisna pasiva taky obsahuji pomocne byt
    return ( 'B', 'F' ) if $tense eq 'post' && ( $aspect eq 'proc' || $voice eq 'passive' );

    return ( 'B', 'P' );
}

1;

__END__

=over

=item Treex::Block::T2A::CS::ResolveVerbs

Finishing the verbal tags and possible adding new nodes in the case
of complex verb forms or reflexive particles. (!!! pozor, vetsina z veci,
ktere byly planovane sem, je realizovana v Add_auxverb...)

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
