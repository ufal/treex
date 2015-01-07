package Treex::Block::A2W::NL::GenerateSentenceAlpino;
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

    my $sent = $self->_generator->generate_sentence($aroot);
    $aroot->get_zone()->set_sentence($sent);
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::GenerateSentenceAlpino

=head1 DESCRIPTION

Generating whole sentences using the Alpino generator.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
