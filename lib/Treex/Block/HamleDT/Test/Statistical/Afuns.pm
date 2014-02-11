package Treex::Block::HamleDT::Test::Statistical::Afuns;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun();
    print "$afun\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Test::Statistical::Afuns

=head1 DESCRIPTION

Prints afuns to the standard output.

=head1 AUTHOR

Jan Mašek <masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
