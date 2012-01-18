package Treex::Block::Write::LayerAttributes::IsActant;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

with 'Treex::Block::Write::LayerAttributes::AttributeModifier';

has '+return_values_names' => ( default => sub { [''] } );

Readonly my $PDT_VALLEX => 'vallex.xml';
Readonly my $LANG => 'cs';


# Return the 1 if this element is governed by valency
sub modify_single {

    my ( $self, $parent_lemma, $parent_sempos, $functor ) = @_;

    return undef if ( !defined($functor) || !defined($parent_sempos) || !defined($parent_lemma) );
    $parent_sempos =~ s/\..*//;

    my @frames = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma( $PDT_VALLEX, $LANG, $parent_lemma, $parent_sempos );
    
    # no frames found, try default actants
    if (@frames == 0){ 
        return $functor =~ m/^(ACT|PAT|ADDR|ORIG|EFF|CPHR|DPHR)$/;
    }   
    # frames found, search within them
    foreach my $frame (@frames){
        return 1 if ($frame->functor($functor));
    }     
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::IsValency

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::IsActant->new(); 
    
    print $modif->modify_all( 'běžet', 'v', 'DIR3' ); # prints '1'
    print $modif->modify_all( 'dělat', 'v', 'DIR3' ); # prints '0'    

=head1 DESCRIPTION

This text modifier takes a lemma, a functor, and a sempos and looks the combination up in the PDT-Vallex valency
lexicon. If the given lemma + sempos combination is found to have the given functor in at least one of its valency
frames, it returns 1. 

If the lemma + sempos combination is not found in PDT-Vallex at all, the modifier resorts to default actants only
as being valency-bound.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
