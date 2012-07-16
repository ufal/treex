package Treex::Tool::Coreference::ContentCandsGetter;

use Moose;
use Treex::Core::Common;

use Treex::Tool::Coreference::ContentWordFilter;

with 'Treex::Tool::Coreference::AnteCandsGetter';

sub _build_cand_filter {
    my ($self) = @_;

    return Treex::Tool::Coreference::ContentWordFilter->new(); 
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::ContentCandsGetter

=head1 DESCRIPTION

Candidates selector. The candidates are content words.

=head1 METHODS

=head2 Already implemented

=over

=item _build_cand_filter

Returns an instance of L<Treex::Tool::Coreference::ContentWordFilter> as 
a content word filter.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

