package Treex::Block::W2A::FixMinus;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_atree {

    my ( $self, $aroot ) = @_;
    my $sent = $aroot->get_zone->sentence();
    my @anodes = $aroot->get_descendants( { ordered => 1 } );

    my ( $past, $current ) = ( '', $sent );

    my $i = 0;
    while ( $i < @anodes ) {

        #log_info('CURRENT: ' . $current );
        #log_info('PAST :' . $past);

        log_info(($anodes[$i]->form eq '-') . '+' . ($current =~ m/^-[0-9]+([,.][0-9]+)?/) . '+' . ($past !~ m/[0-9]$/));

        if ( $anodes[$i]->form eq '-' && $current =~ m/^-[0-9]+([,.][0-9]+)?/ && $past =~ m/\s$/ && $past !~ m/[0-9]\s*$/ ) {
            
            #log_info('FIRED');
            
            $anodes[ $i + 1 ]->set_form( '-' . $anodes[ $i + 1 ]->form );

            my ($aligns) = $anodes[$i]->get_aligned_nodes();
            foreach my $align ( @{$aligns} ) {
                $align->delete_aligned_node( $anodes[$i] );
            }
            $anodes[$i]->remove;
            ++$i;
        }
        
        my $form = $anodes[$i]->form;
        if ( $form =~ m/^(``|''|--)$/ && $current =~ m/["“”«»—"]/ ){
            $current = substr( $current, 1 );
        }
        else {
            $current = substr( $current, length($form) );
        } 
        $current =~ s/^(\s*)//;
        $past .= $form . $1;
        ++$i;
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::FixMinus

=head1 DESCRIPTION

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
