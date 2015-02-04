package Treex::Block::A2T::SetSentmod;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_ttree {
    my ($self, $t_root) = @_;
    my $t_sent_root = $t_root->get_children( { first_only => 1 } ) or return;
    
    # Default is the normal indicative mood
    my $sentmod = 'enunc';
    
    # Questions
    my $a_root = $t_root->get_zone()->get_atree();
    if ($self->is_question($a_root)){
        $sentmod = 'inter';
    }

    # The head of the main clause is imperative => the whole sentence is imper.
    elsif ($self->is_imperative($a_root)){
        $sentmod = 'imper';
    }
    
    $t_sent_root->set_sentmod($sentmod);
    return;
}

# Example implementation: using "?" at the end of the sentence to detect the question
sub is_question {
    my ($self, $a_root) = @_;
    my ($last_token, @toks) = reverse $a_root->get_descendants( { ordered => 1 } );
    if (@toks && $last_token->afun eq 'AuxG'){
        $last_token = shift @toks;
    }
    if ($last_token && $last_token->form eq '?'){
        return 1;
    }
    return 0;
}

# Example implementation: works for Czech and English
sub is_imperative {
    my ($self, $a_root) = @_;

    # Use only the first child
    my $a_node = $a_root->get_children( { first_only => 1 } ); 
    
    # For PDT-like tagset
    return 1 if $a_node->tag =~ /^Vi/;
        
    # For English:  imperative is an infinitive verb (VB) with no left children
    return 1 if $a_node->tag eq 'VB' && !$a_node->get_children( { preceding_only => 1 } );    
    
    return 0;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetSentmod - fill sentence modality (question, imperative)

=head1 DESCRIPTION

T-layer sentmod attribute is filled based on the main verb and the last punctuation token.
Override the is_imperative method for language-specific behavior.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
