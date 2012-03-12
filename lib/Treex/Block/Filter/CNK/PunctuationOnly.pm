package Treex::Block::Filter::CNK::PunctuationOnly;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    
    my ( $self, $document ) = @_;
    
    my @bundles = $document->get_bundles();
    
    for (my $i = 0; $i < @bundles; ++$i){
        
        my $sent = $bundles[$i]->get_zone('cs')->sentence;
        
        if ( _is_too_much_punct( $sent ) ){
            log_info('REMOVING : ' . $sent );
            $bundles[$i]->remove;
        }
    }
    return 1;
}


# Returns 1 if there's more punctuation than the rest of the characters
sub _is_too_much_punct {
    my ($sent) = @_;
    
    $sent =~ s/\s//g;
    my $punct = ($sent =~ s/([^\P{Punct}%]|\|)//g); # include '|' in punctuation, exclude '%' 
    my $rest = length($sent);
    
    return 1 if ($punct > $rest);
    return 0;
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
