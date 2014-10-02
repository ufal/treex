package Treex::Block::T2A::NL::CopyTtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::CopyTtree';

after 'process_zone' => sub {
    my ( $self, $zone ) = @_;
    my $a_root = $zone->get_atree();
    foreach my $a_node ($a_root->get_descendants()){
        my $lemma = $a_node->lemma // '';
        if ($lemma =~ s/^zich_//){
            $a_node->set_lemma($lemma);
        }
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::CopyTtree

=head1 DESCRIPTION

Inherit the language-independent code of C<T2A::CopyTtree>
and moreover strip reflexive verb particles I<zich>.

=head1 SEE ALSO

L<Treex::Block::T2A::CopyTtree>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz> 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
