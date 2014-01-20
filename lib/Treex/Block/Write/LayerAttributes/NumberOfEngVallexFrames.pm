package Treex::Block::Write::LayerAttributes::NumberOfEngVallexFrames;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;

extends 'Treex::Block::Write::LayerAttributes::NumberOfVallexFrames';

has 'lexicon' => ( isa => 'Str', is => 'ro', default => 'engvallex.xml' );

has 'lang' => ( isa => 'Str', is => 'ro', default => 'en' );

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::LayerAttributes::NumberOfEngVallexFrames

=head1 SYNOPSIS

    my $modif = Treex::Block::Write::LayerAttributes::NumberOfEngVallexFrames->new();
    
    print $modif->modify_all( 'like' );

=head1 DESCRIPTION

This text modifier takes a lemma, looks it up in the EngVallex valency lexicon, and returns
the number of frames matching the lemma.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
