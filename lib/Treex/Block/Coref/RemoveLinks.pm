package Treex::Block::Coref::RemoveLinks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'type' => ( is => 'ro', isa => enum([qw/all gram text all+special/]), default => 'all' );

sub process_tnode {
    my ( $self, $tnode ) = @_;

#    if ($self->type eq 'expressed') {
#        return if ($tnode->is_generated);
#    }

    if ($self->type eq 'text') {
        $tnode->set_attr( 'coref_text.rf', undef );
    }
    elsif ($self->type eq 'gram') {
        $tnode->set_attr( 'coref_gram.rf', undef );
    }
    elsif ($self->type eq 'all') {
        $tnode->set_attr( 'coref_gram.rf', undef );
        $tnode->set_attr( 'coref_text.rf', undef );
    }
    else {
        $tnode->set_attr( 'coref_gram.rf', undef );
        $tnode->set_attr( 'coref_text.rf', undef );
        $tnode->set_attr( 'coref_special', undef );
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::Coref::RemoveLinks

=head1 DESCRIPTION

Removes coreference links from tectogrammatical trees.

=head1 PARAMETERS

=over

=item type

Which type of coreference link should be deleted. Possible values:
gram - grammatical coreference,
text - textual coreference,
all - grammatical and textual coreference,
all+special - grammatical, textual and special coreference.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
