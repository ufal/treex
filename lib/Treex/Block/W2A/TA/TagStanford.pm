package Treex::Block::W2A::TA::TagStanford;

use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TagStanford';

has '+model' => ( 
	default => 'installed_tools/tagger/stanford/models/tamil-TamilTB-pdtstyle.model' 
);

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TA::TagStanford - Stanford tagger for tagging Tamil sentences.

=head1 DESCRIPTION

This block loads L<Treex::Tool::Tagger::Stanford> (a wrapper for the Stanford tagger) with 
the given C<model>,  feeds it with all the input tokenized sentences, and fills the C<tag> 
parameter of all a-nodes with the tagger output. 

=head1 PARAMETERS

=over

=item C<model>

The path to the tagger model within the shared directory. This parameter is required. The default tagger is a 
model trained with positional tagset (15 positions) as used in PDT. The default model 
is available at C<$TMT_ROOT/share/installed_tools/tagger/stanford/models/tamil-TamilTB-pdtstyle.model>. 

=back

=head1 AUTHORS

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
