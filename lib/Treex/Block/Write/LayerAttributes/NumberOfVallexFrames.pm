package Treex::Block::Write::LayerAttributes::NumberOfVallexFrames;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

has 'lexicon' => ( isa => 'Str', is => 'ro', default => 'vallex.xml' );

has 'lang' => ( isa => 'Str', is => 'ro', default => 'cs' );

# Return the 1 if this element is governed by valency
sub modify_single {

    my ( $self, $lemma ) = @_;

    return undef if ( !defined($lemma) );
    $lemma =~ s/_/ /g;

    my @frames = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma( $self->lexicon, $self->lang, $lemma );

    # return the number of frames
    return scalar(@frames);
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::NumberOfVallexFrames

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::NumberOfVallexFrames->new(); 
    
    print $modif->modify_all( 'běžet' ); # prints '7'
    print $modif->modify_all( 'googlit' ); # prints '0' (not in PDT-VALLEX)    

=head1 DESCRIPTION

This text modifier takes a lemma, looks it up in the PDT-Vallex valency lexicon, and returns
the number of frames matching the lemma.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
