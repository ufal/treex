package Treex::Block::Util::FixPMLStructure;
use Treex::Core::Common;
use Moose;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    for my $b ($document->get_bundles) {
        for my $z ($b->get_all_zones) {
            for my $t ($z->get_all_trees) {
                # check node order
                for my $node ( $t, $t->descendants ) {
                    my @children = $node->get_children({ordered => 1});

                    next unless @children;

                    my $current = shift @children;
                    my $next = shift @children;
                    $node->set_firstson($current);
                    $current->set_lbrother(undef);
                    $current->set_rbrother($next);
                    $next->set_lbrother($current) if $next;
                    $next->set_rbrother(undef) if $next;

                    while (@children) {
                        $current = $next;
                        $next = shift @children;

                        $current->set_rbrother($next);
                        $next->set_lbrother($current);
                        $next->set_rbrother(undef);
                    }
                }
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Util::FixPMLStructure

=head1 DESCRIPTION

Fix node order in underlying PML structure

=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_document

=back

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
