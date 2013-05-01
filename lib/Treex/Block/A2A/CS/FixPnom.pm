package Treex::Block::A2A::CS::FixPnom;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    #my $endep = $self->en($dep);

    if (#$d->{afun} eq 'Pnom' && 
        $d->{'pos'} eq 'A'
        && $g->{'pos'} eq 'V') {
        my @subjects = grep {
            $_->afun eq 'Sb' &&
            $self->en($_) && $self->en($_)->afun && $self->en($_)->afun eq 'Sb'
        } $gov->get_echildren();
        if ( @subjects ) {
            # my $subject = $subjects[@subjects-1];
            my ($subject) = @subjects;
            $self->logfix1( $dep, "Pnom" );
            $self->set_node_tag_cat( $dep, 'number',
                $self->get_node_tag_cat( $subject, 'number'));
            $self->set_node_tag_cat( $dep, 'gender',
                $self->get_node_tag_cat( $subject, 'gender'));
            $self->set_node_tag_cat( $dep, 'case', 1);
            $self->regenerate_node($dep);
            $self->logfix2($dep);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPnom

=head1 DESCRIPTION


=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
