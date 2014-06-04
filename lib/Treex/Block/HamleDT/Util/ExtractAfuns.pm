package Treex::Block::HamleDT::Util::ExtractAfuns;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_atree {
    my $self = shift;
    my $a_root = shift;
    my $language = $a_root->get_zone->language();
    for my $anode ($a_root->get_descendants( { add_self => 1 } )) {
	my $afun = $anode->afun();
	print "$language\t$afun\n";
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Util::ExtractAfuns

=head1 DESCRIPTION

For each node in a tree, prints a language code and afun to the standard output.

=head1 AUTHOR

Jan Mašek <masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
