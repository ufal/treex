package Treex::Block::T2A::ES::GenerateWordforms;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Flect::FlectBlock';

has '+model_file' => ( default => 'data/models/flect/model-es.pickle.gz');

has '+features_file' => ( default => 'data/models/flect/model-es.features.yml' );


sub process_atree {
    my ( $self, $aroot ) = @_;
    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    
    # Remove Interset "gender" feature from verbs,
    # it was copied there from t-layer (gram/gender),
    # but Spanish verbs have no inflection for gender (as far as I know).
    # Unfortunatelly, Flect gets easily confused by extra features.
    foreach my $anode (@anodes) {
        if ($anode->is_verb){
            my $reduced_tag = $anode->tag;
            $reduced_tag =~ s/ (masc|fem)//;
            $reduced_tag =~ s/verb sing 3 ind pres/verb sing 3 fin ind pres/;
            $anode->set_tag($reduced_tag);
        }
    }
    
    my @forms = $self->inflect_nodes(@anodes);

    for ( my $i = 0; $i < @anodes; ++$i ) {
        if ( not defined( $anodes[$i]->form ) ) {
            $anodes[$i]->set_form( $forms[$i] );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::GenerateWordforms

=head1 DESCRIPTION

Generating word forms using the Flect tool. Contains pre-trained model settings for Spanish.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
