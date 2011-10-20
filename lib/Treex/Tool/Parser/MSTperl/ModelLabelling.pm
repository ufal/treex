package Treex::Tool::Parser::MSTperl::ModelLabelling;

use Moose;

extends 'Treex::Tool::Parser::MSTperl::ModelBase';

# has the from of:
#  transitions->{label_prev}->{label_this} = count
# unigram counts stored as:
#  transitions->{label_this}->{$config->UNIGRAM_PROB_KEY} = count
has 'transitions' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub add_transition {
    my ($self, $label_first, $label_second) = @_;
    
    $self->transitions->{$label_first}->{$self->config->UNIGRAM_PROB_KEY} += 1;
    if ($label_second) {
        $self->transitions->{$label_first}->{$label_second} += 1;
    }
    
    return;
}


1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelLabelling

=head1 DESCRIPTION

This is an in-memory represenation of a labelling model,
extended from L<Treex::Tool::Parser::MSTperl::ModelBase>.

=head1 FIELDS

=head2 Feature weights

=over 4

=item 

=back

=head1 METHODS

=over 4

=item

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
