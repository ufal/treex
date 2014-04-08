package Treex::Tool::Segment::RU::RuleBased;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';

# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{
    \p{Upper}            # single uppercase letters (with a rare exception of I)
    |см\.|напр\.|т\.д\.|т\.п\.|т\.е\.|др\.|пр\.|т\.е\.|ср\.|   
    |д\.ф\.н\.|инж\.|канд\.|доц\.|проф\.|    # titles before names of persons, etc.
    |г\-жа|г\-н|тов\.|им\.|ул\.|гр\.|г\.|млн|млрд|коп\.|руб\.|чел\.|шт\.|
    |г\.|н\.э\.|н\.ст\.|ст\.|  #others
}x;    ## no critic (RegularExpressions::ProhibitComplexRegexes) this is nothing complex, just list

override unbreakers => sub {
    return $UNBREAKERS;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Segment::EN::RuleBased - rule based sentence segmenter for English

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.
This class adds a English specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter.

See L<Treex::Block::W2A::Segment>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

