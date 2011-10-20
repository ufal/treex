package Treex::Tool::Parser::MSTperl::ModelUnlabelled;

use Moose;

extends 'Treex::Tool::Parser::MSTperl::ModelBase';

sub BUILD {
    my ($self) = @_;
    
    $self->featuresControl($self->config->unlabelledFeaturesControl);
    
    return;
}

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ModelUnlabelled

=head1 DESCRIPTION

This is an in-memory represenation of a parsing model,
extended from L<Treex::Tool::Parser::MSTperl::ModelBase>.

=head1 FIELDS

=head2 

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
