package Treex::Block::W2A::RU::Segment;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::Segment';

has segmenter => (
    is         => 'ro',
    handles    => [qw(get_segments)],
    lazy_build => 1,
);

use Treex::Tool::Segment::RU::RuleBased;

sub _build_segmenter {
    my $self = shift;
    return Treex::Tool::Segment::RU::RuleBased->new(
        use_paragraphs => $self->use_paragraphs,
        use_lines      => $self->use_lines
    );
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::EN::Segment

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds an English specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

=head1 SEE ALSO

L<Treex::Block::W2A::Segment>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
