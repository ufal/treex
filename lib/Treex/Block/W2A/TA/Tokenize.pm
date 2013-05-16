package Treex::Block::W2A::TA::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';


override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    $sentence =~ s/^(.*)$/ $1 /;	
	$sentence =~ s/(^\s+|\s+$)//;
	$sentence =~ s/\s+/ /g;	
    return $sentence;    
};


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TA::Tokenize - Tamil Tokenizer


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
