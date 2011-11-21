package Treex::Block::W2A::CS::FixMorphoErrors;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {

    my ( $self, $anode ) = @_;

    return if ( $anode->is_root );

    # fix the '*', '!' and '%' signs (not recognized by the morphology)
    if ( $anode->form =~ m/^(\*|!)$/ ){
        $anode->set_tag('Z:-------------');
    }
    # treat '%' as a noun abbreviation 
    elsif ( $anode->form eq '%' ){
        $anode->set_tag('NNIXX-----A---8');
    }
    # fix Czech decimal numerals
    elsif ( $anode->form =~ m/[0-9]\+,[0-9]\+/ ){
        $anode->set_tag('C=-------------');
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::CS::FixMorphoErrors

=head1 DESCRIPTION

An attempt to (hopefully temporarily) fix some of the most common current tagger errors:

=over

=item *

Sets the tag 'Z:' for asterisks ("*") and exclamation marks ("!").

=item *

Sets the tag 'NNIXX-----A---8' for percent signs (even though it's marked 'Z:' in Czech National Corpus and PDT), 
since parsing works better with this tag and in an analogous case, the degree sign and the 'Kč' sign get the same tag
(except for gender).

=item *

Sets the tag 'C=' for Czech numbers with decimal comma.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
