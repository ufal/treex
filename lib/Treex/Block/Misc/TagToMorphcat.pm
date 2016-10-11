package Treex::Block::Misc::TagToMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_anode {
    my ($self, $anode) = @_;

    return if (!$anode->tag);

    my ($pos, $subpos, $gender, $number, $case, $possgender, $possnumber, 
        $person, $tense, $grade, $negation, $voice) = split //, $anode->tag;
    
    $anode->reset_morphcat();
    $anode->set_morphcat_pos($pos);
    $anode->set_morphcat_subpos($subpos);
    $anode->set_morphcat_gender($gender);
    $anode->set_morphcat_number($number);
    $anode->set_morphcat_case($case);
    $anode->set_morphcat_possgender($possgender);
    $anode->set_morphcat_possnumber($possnumber);
    $anode->set_morphcat_person($person);
    $anode->set_morphcat_tense($tense);
    $anode->set_morphcat_grade($grade);
    $anode->set_morphcat_negation($negation);
    $anode->set_morphcat_voice($voice);

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Misc::TagToMorphcat -- copy information from the tag to morphcat

=head1 DESCRIPTION

Fill the morphcat structure according to the morphological tag. Czech positionl tags
are expected.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
