package Treex::Block::A2T::SetGrammatemesFromAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# my @RULES = (
#     'adjtype=art definiteness=def' => 'definiteness=definite',
#     'adjtype=art definiteness=ind' => 'definiteness=indefinite',
# );

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my @anodes = $tnode->get_aux_anodes();
    return if !@anodes;
    return if $tnode->nodetype ne 'complex';

    foreach my $anode (@anodes) {
        # TODO: delete the adjtype condition
        # adjtype is deprecated in Interset, but prontype cannot have value "det"
        if ($anode->iset->adjtype =~ /^(art|det)$/ || $anode->iset->prontype eq 'art'){
            my $d = $anode->iset->definiteness;
            $tnode->set_gram_definiteness('definite') if $d eq 'def';
            $tnode->set_gram_definiteness('indefinite') if $d eq 'ind';

            # Personal names (Manuel, Maria) are missing gender and number
            if (!$tnode->gram_gender){
                my $gender = $anode->iset->gender || '';
                $gender =~ s/masc/anim/;
                $gender =~ s/com/inher/;
                $tnode->set_gram_gender($gender);
            }
            if (!$tnode->gram_number){
                my $number = $anode->iset->number || '';
                $number =~ s/sing/sg/;
                $number =~ s/plu/pl/;
                $tnode->set_gram_number($number);
            }
        }
        $self->check_anode($tnode, $anode);
    }

    return;
}

sub check_anode {
    my ($self, $tnode, $anode) = @_;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetGrammatemesFromAux

=head1 DESCRIPTION

A very basic, language-independent grammateme setting block for t-nodes. 
Grammatemes are set based on the Interset features (and formeme)
of the corresponding auxiliary a-nodes.

So far, only definiteness is handled (i.e. definite and indefinite articles).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
