package Treex::Block::A2T::EU::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;
    
    my $sentmod;
    #my $anode = $tnode->get_lex_anode();
    #if ($anode && $anode->is_verb){
        my @aux_anodes = $tnode->get_aux_anodes();
        if (any {$_->form =~ /^[?]$/} @aux_anodes){
            $sentmod = 'inter';
        } elsif (any {$_->form =~ /^[!]$/} @aux_anodes){
            $sentmod = 'imper';
        }
    #}
    
    # The main verb should have sentmod filled. Default is the normal indicative mood.
    if (!$sentmod && $tnode->get_parent()->is_root()){
        $sentmod = 'enunc';
    }
    
    $tnode->set_sentmod($sentmod) if $sentmod;
    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EU::SetSentmod - fill sentence modality (question, imperative)

=head1 DESCRIPTION

T-layer sentmod attribute is filled based on punctuation tokens ("¿", "?", "¡" and "!").

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
