package Treex::Block::T2A::NL::Alpino::FixNamedEntities;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';
with 'Treex::Block::T2A::NL::Alpino::MWUs';


has '+if_missing_tree' => ( default => 'warn' );

sub process_nnode {
    my ( $self, $nnode ) = @_;

    # only do this for the outermost n-nodes (assume the references are fixed)
    return if ( !$nnode->get_parent->is_root );

    # get all a-nodes and find one that will be used as the head of the NE structure
    my @anodes = $nnode->get_anodes();
    
    if ( @anodes > 1 ){
        # create the MWU structure and get its formal head        
        my $amwu_root = $self->create_mwu(@anodes);
        # link to the formal head from n-layer to ensure correct ADTXML output
        $nnode->set_anodes( @anodes, $amwu_root );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixNamedEntities

=head1 DESCRIPTION

Flattening multi-word named entities and pre-setting their Alpino relation 
(both C<wild-&gt;{adt_phrase_rel}> and C<wild-&gt;{adt_term_rel}>).
to "mwp".

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
