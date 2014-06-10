package Treex::Block::HamleDT::Util::PrintRoots;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has tag => ( is => 'rw', isa => 'Str', default => 'auto' );

sub tsvsay {
    my $line = join "\t", @_;
    print "$line\n";
}

sub process_atree {
    my ($self, $technical_root) = @_;
    my $language = $technical_root->get_zone->language();
    my $real_root = $technical_root->get_children( {first_only => 1});
    my $tag = $self->tag eq 'auto' ?
        ($real_root->tag ? $real_root->tag : $real_root->conll_pos)
        : $real_root->get_attr($self->tag);
    tsvsay($language, $tag);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Util::PrintRoots

=head1 DESCRIPTION

For each non-technical root of an a tree (i.e. the first child of the technical
root), prints the language code and tag to the standard output.

=head1 PARAMETERS

=over

=item tag

The attribute that provides the tag. Recommended values are:

=over

=item C<tag>

=item C<conll/pos>

=item C<conll/cpos>

=item C<auto> -- C<tag> if set, otherwise C<conll/pos>

=back

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
