package Treex::Block::A2T::SetGrammatemesFromAuxForPT;
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


        # TODO: Create as a specific PT block
        $tnode->set_gram_definiteness('definite')   if ($anode->iset->prontype eq 'prn' && $anode->lemma eq 'the');
        $tnode->set_gram_definiteness('indefinite') if ($anode->iset->prontype eq 'prn' && $anode->lemma =~ /^(a|an)$/);
        
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
                $number =~ s/plur/pl/;
                $tnode->set_gram_number($number);
            }
        }

        #Modal verbs
        if ($anode->lemma eq "poder") { # TODO better to turn it into a hash
            $tnode->set_gram_deontmod("poss");
        }
        elsif ($anode->lemma eq "querer") {
            $tnode->set_gram_deontmod("vol");
        }
        elsif ($anode->lemma eq "dever") {
            $tnode->set_gram_deontmod("deb");
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

Sets the deontmod grammatemes for Portuguese modal verbs (poder,querer e dever)

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
