package Treex::Block::Util::FixInvalidIDs;

use Treex::Core::Common;
use Moose;
extends 'Treex::Core::Block';

has action => (
    is=>'ro',
    default=>'warn',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $doc = $zone->get_document();

    foreach my $tnode ($zone->get_ttree()->get_descendants()){
        my $lex_rf = $tnode->get_attr('a/lex.rf');
        if (!defined $lex_rf) {
            log_warn "Missing id in a/lex.rf of " . $tnode->get_address if $self->action eq 'warn';
        }
        elsif (!$doc->id_is_indexed($lex_rf)){
            $tnode->set_lex_anode(undef);
            log_warn "Missing node with id $lex_rf in a/lex.rf of " . $tnode->get_address if $self->action eq 'warn';
        }
        my $aux_rfs = $tnode->get_attr('a/aux.rf');
        if ($aux_rfs){
            my @filtered = grep {defined $_ && $doc->id_is_indexed($_)} @$aux_rfs;
            if (@filtered != @$aux_rfs){
                $tnode->set_attr('a/aux.rf', \@filtered);

                if ($self->action eq 'warn') {
                    foreach my $aux_rf (@$aux_rfs){
                        if (!defined $aux_rf) {
                            log_warn "Missing id in a/aux.rf of " . $tnode->get_address;
                        } elsif (!$doc->id_is_indexed($aux_rf)){
                            log_warn "Missing node with id $aux_rf in a/aux.rf of " . $tnode->get_address;
                        }
                    }
                }
            }
        }
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Util::FixInvalidIDs

=head1 DESCRIPTION

If there is a *.rf attribute with id which is not present in the document,
delete this id. The current implementation checks only a/lex.rf and a/aux.rf.

Such situation should never happen, but if we have invalid data on the input,
this block may be handy.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
