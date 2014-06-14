package Treex::Tool::Interset::Example::Simple;
use utf8;
use Moose;
with 'Treex::Tool::Interset::SimpleDriver';

# See https://wiki.ufal.ms.mff.cuni.cz/user:zeman:interset:features
my $DECODING_TABLE = {
    ADJ     => { pos => 'adj' }, # Adjective
    ART     => { pos => 'adj', subpos => 'art' }, # Article
    INT     => { pos => [qw(noun adv)], prontype => 'int'}, # Interrogative (pro)noun ("who") or (pro)adverb ("why")
};

sub decoding_table {
    return $DECODING_TABLE;
}

1;

__END__

=head1 NAME

Treex::Tool::Interset::Example::Simple - for demo and tests

=head1 SYNOPSIS

 ######## From Treex scenario
 A2A::ConvertTagsInterset input_driver=Example::Simple

 ######## From Perl code
 use Treex::Tool::Interset::Example::Simple;
 my $driver = Treex::Tool::Interset::Example::Simple->new();
 my $iset = $driver->decode('ART');
 # $iset = { pos => 'adj',  subpos => 'art', tagset => 'Example::Simple' };
 my $tag = $driver->encode({ pos => 'adj',  subpos => 'art' });

=head1 DESCRIPTION

Conversion between a toy tagset with three tags and Interset (universal tagset by Dan Zeman).

=head1 SEE ALSO

L<Treex::Tool::Interset::Driver>

L<Treex::Block::A2A::ConvertTagsInterset>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
