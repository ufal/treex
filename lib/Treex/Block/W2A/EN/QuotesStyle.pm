package Treex::Block::W2A::EN::QuotesStyle;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has output => (is=>'ro', default=>'vertical'); # TODO ``tex'', "vertical", “curly”, «guillemet», single-curly, single-vertical, nesting?
has input => (is=>'ro', default=>'tex'); #TODO autodetect
has attributes => (is=>'ro', isa=>'Str', default=>'form,lemma');

sub process_anode {
    my ( $self, $node ) = @_;

    foreach my $attr (split /,/, $self->attributes){
        my $value = $node->get_attr($attr);
        if ($value eq q{``} || $value eq q{''}){
            $node->set_attr($attr, q{"});
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::QuotesStyle - change quotation marks

=head1 DESCRIPTION

Opening and closing quotation marks have different styles:
``tex'', "vertical", “curly”, «guillemet».
This block should convert between these styles.
Currently, it supports only from tex to vertical.

By default, it converts both lemmas and forms (cf. parameter C<attributes>).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

