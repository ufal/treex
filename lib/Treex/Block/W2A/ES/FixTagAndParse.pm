package Treex::Block::W2A::ES::FixTagAndParse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;
    my $lemma = $anode->lemma;
    #my $parent = $anode->get_parent();
    
    # "luces estén encendidas(lemma=encendidas -> encendido)"
    if ($anode->matches(pos=>'adj', verbform=>'part')){
        $lemma =~ s/s$// if $anode->is_plural;
        $lemma =~ s/a$// if $anode->is_feminine;
        $lemma .= 'o' if $lemma !~ /o$/;
        $anode->set_lemma($lemma);
    }
    
    
    #=== The following are issues of HamleDT::ES::Harmonize rather than W2A::ES::TagAndParse
    if ($lemma eq 'uno' && $anode->conll_deprel eq 'spec'){
        $anode->iset->set_prontype('art');
    }
    if ($anode->is_article){
        $anode->set_afun('AuxA');
        $anode->iset->set_definiteness($lemma eq 'el' ? 'def' : 'ind');
    }
    
    $anode->set_tag(join ' ', $anode->get_iset_values);
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::ES::FixTagAndParse - fix IXA-Pipes errors

=head1 DESCRIPTION


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
