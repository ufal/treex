package Treex::Block::Filter::CNK::DocIds;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    
    my ( $self, $document ) = @_;
    
    my @bundles = $document->get_bundles();
    
    for (my $i = 0; $i < @bundles; ++$i){
        
        my $sent = $bundles[$i]->get_zone('cs')->sentence;
 
        if ( $sent =~ m/^\s*\&doc;\s*$/ ){ # document start indication
            $bundles[$i]->remove;
        }
        if ( $sent =~ m/^\s*[A-Za-z0-9]{1,8}\.[tT]6\s*$/ ){ # T602 (?) file names
            $bundles[$i]->remove;
        }
    }
    return 1;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::Filter::CNK::PunctuationOnly

=head1 DESCRIPTION


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
