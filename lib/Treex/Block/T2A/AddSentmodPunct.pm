package Treex::Block::T2A::AddSentmodPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'open_punct' => ( is => 'ro', 'isa' => 'Str', default => '[‘“\']' );

has 'close_punct' => ( is => 'ro', 'isa' => 'Str', default => '[’”\']' );

sub process_ttree {
    my ( $self, $troot ) = @_;

    my @sentmod_tnodes;
    my $main_verb_tnode;
    foreach my $sentmod_tnode (grep {$_->sentmod} $troot->get_descendants()){
        if ($sentmod_tnode->get_parent->is_root){
            $main_verb_tnode = $sentmod_tnode;
        } else {
            push @sentmod_tnodes, $sentmod_tnode;
        }
    }
    
    foreach my $sentmod_tnode (@sentmod_tnodes){
        $self->add_sentmod_punct($sentmod_tnode, 0);
    }
    
    if ( $main_verb_tnode ) {
        $self->add_sentmod_punct($main_verb_tnode, 1);
    }
    return;
}
    
sub add_sentmod_punct{
    my ($self, $tnode, $is_main) = @_;
    my $anode = $tnode->get_lex_anode or return;
    
    # Don't put period after colon, semicolon, three dots or other sentmod punct
    my $last_anode = $anode->get_descendants( { last_only => 1, add_self => 1 } );
    return if $last_anode->lemma =~ /^[:;.?!]/;
    
    my $punct_mark = '';
    if ($tnode->sentmod eq 'inter') { $punct_mark = '?' }
    elsif ($is_main || $tnode->is_dsp_root){
        $punct_mark = $tnode->sentmod eq 'imper' ? '!' : '.';
    }
    return if !$punct_mark;
    

    my $punct = $anode->create_child(
        {   'form'          => $punct_mark,
            'lemma'         => $punct_mark,
            'afun'          => 'AuxK',
            'morphcat/pos'  => 'Z',
            'clause_number' => 0,
        }
    );
    $punct->iset->set_pos('punc');

    # The $punct goes to the end, except for some sentences with quotes:
    #   Do you know the word "pun"?
    #   "How are you?"
    if ( $self->_ends_with_clause_in_quotes( $tnode->get_descendants( { last_only => 1, add_self => 1 } ) ) ) {
        $punct->shift_before_node($last_anode);
    }
    else {
        $punct->shift_after_subtree($anode);
    }

    $self->postprocess($punct, $tnode, $is_main);

    return;
}

# To be implemented in language-specific child blocks
sub postprocess {
    return;
}

sub _ends_with_clause_in_quotes {
    my ( $self, $last_tnode ) = @_;
    my ( $open_punct, $close_punct ) = ( $self->open_punct, $self->close_punct );

    return 0 if $last_tnode->t_lemma !~ /$close_punct/;
    my @toks = $last_tnode->get_root->get_descendants( { ordered => 1 } );
    while ($toks[-1] != $last_tnode) {pop @toks};
    pop @toks;
    while (@toks) {
        my $tok = pop @toks;
        return 0 if $tok->t_lemma =~ /$open_punct/;
        return 1 if $tok->is_clause_head();
    }
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddSentmodPunct - add period, question mark or exclamation mark

=head1 DESCRIPTION

Add punctuation-mark a-nodes corresponding to the C<sentmod> attribute of t-nodes.
Usually the a-node is added at the end of the whole sentence, except for:
- If the last clause is enclosed in quotes, the final punctuation mark goes before the close quotes.
- Attribute C<sentmod> may be set not only for the main verb t-node,
  but also for root of direct-speech or another clause.
  In Spanish, it is quite common to have a just a part of sentence enclosed in question marks (¿ and ?).
  
See http://ufal.mff.cuni.cz/pdt3.0/documentation#__RefHeading__20_1200879062

Sentmod values are

    enunc - declarative modality (assertions)

    excl - exclamative modality (exclamations)

    desid - desiderative modality (wishes)

    imper - imperative modality (requests/orders)

    inter - interrogative modality (questions)


=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
