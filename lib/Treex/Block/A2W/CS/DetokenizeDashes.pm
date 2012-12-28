package Treex::Block::A2W::CS::DetokenizeDashes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;

    if ( $sentence =~ /\-/ ) {
        
        # 18- letý -> 18 letý
        $sentence =~ s/\b([0-9\.,]+)- /$1 /g;
        
        # ex- královna -> ex-královna
        $sentence =~ s/\b([\w]{1,2})- /$1-/g;
        
        # anti- pneumokokový -> anti pneumokokový
        $sentence =~ s/\b([\w]{3,})- /$1 /g;
        
        # UN -based -> UN based
        $sentence =~ s/ -([\w]{3,})\b/ $1/g;

    }
    
    if ( $sentence =~ /[0-9]/ ) {
        
        # 18m -> 18 m
        $sentence =~ s/\b([0-9\.,\-]+)([mcdhkMG]?[mglsbBVA]|h|min)\b/$1 $2/ig;
    }

    $zone->set_sentence($sentence);

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::CS::DetokenizeDashes
- a Depfix block.

=head1 DESCRIPTION

Changes tokenization around dashes, removing spaces and/or the dashes.

To be used especially to fix weird dashes tokenization
after having applied the
L<Treex::Block::W2W::ProjectTokenization> block.

The changes made are of four categories, shown by examples here (see source code
if you want to know exactly what happens there).

=over

=item "18- letý" -> "18 letý" (for numbers)

=item "ex- královna" -> "ex-královna" (if length is 1 or 2)

=item "anti- pneumokokový" -> "anti pneumokokový" (if longer)

=item "UN -based" -> "UN based" (the other direction is not granularized)

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
