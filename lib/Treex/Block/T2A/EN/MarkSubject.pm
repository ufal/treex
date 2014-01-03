package Treex::Block::T2A::EN::MarkSubject;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my @tnodes = $t_root->get_descendants( { ordered => 1 } );
    
    foreach my $t_vfin ( grep { $_->formeme =~ /^v.+(fin|rc)/ } @tnodes ) {

        if ( my $a_subj = _find_subject($t_vfin) ) {
            $a_subj->set_afun('Sb');
        }
    }

}

sub _find_subject {
    my ($t_vfin) = @_;

    my @candidates = (
        ( reverse $t_vfin->get_echildren( { preceding_only => 1 } ) ),
        $t_vfin->get_echildren( { following_only => 1 } )
    );

    @candidates = grep { $_->formeme eq 'n:subj' } @candidates;
    return if !@candidates;
    return $candidates[0]->get_lex_anode();
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::MarkSubject

=head1 DESCRIPTION

Subjects of finite clauses are distinguished by
filling the afun attribute.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
