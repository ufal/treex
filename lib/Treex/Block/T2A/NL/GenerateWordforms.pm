package Treex::Block::T2A::NL::GenerateWordforms;
use Moose;
use Treex::Core::Common;
use Treex::Tool::FormsGenerator::Alpino;

extends 'Treex::Core::Block';

has '_generator' => ( is => 'rw', builder => '_build_generator' );

sub _build_generator {
    return Treex::Tool::FormsGenerator::Alpino->new();
}



sub process_atree {
    my ( $self, $aroot ) = @_;    

    foreach my $anode ( grep { not defined $_->form } $aroot->get_descendants( { ordered => 1 } ) ){        
        my $lemma = $anode->lemma // '';
        my $form = $self->_generator->generate_form($anode);
        if ($form ne ''){
            if ($lemma eq lcfirst $lemma){
                $form = lcfirst $form;    
            }            
        }
        $anode->set_form($form ne '' ? $form : $lemma);
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::GenerateWordforms

=head1 DESCRIPTION

Generating word forms using the Alpino generator.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
