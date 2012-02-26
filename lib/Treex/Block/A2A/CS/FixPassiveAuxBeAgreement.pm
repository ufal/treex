package Treex::Block::A2A::CS::FixPassiveAuxBeAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if ( $g->{tag} =~ /^Vs/ && $d->{tag} =~ /^Vp/
        && $gov->ord > $dep->ord
        && ( $g->{gen} . $g->{num} ne $d->{gen} . $d->{num} )
    ) {
        my $tag = $g->{tag};
        my $new_gn = $d->{gen} . $d->{num};
        $tag =~ s/^(..)../$1$new_gn/;

        $self->logfix1( $dep, "PassiveAuxBeAgreement" );
        $self->regenerate_node( $gov, $tag );
        $self->logfix2($dep);
    }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPassiveAuxBeAgreement - Fixing agreement between
passive and auxiliary verb 'to be'.

=head1 DESCRIPTION

If passive participle and dependent auxiliary 'be' do not agree in gender
and/or number, the parent verb takes the categories from the child verb.

=head1 AUTHORS

David Marecek <marecek@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
